require 'palletjack'
require 'fileutils'
require 'optparse'
require 'singleton'
require 'rugged'

class PalletJack

  # Superclass for PalletJack tool implementations
  #
  # Provides convenience methods for option parsing, file generation,
  # and warehouse structure management.
  #
  # Example:
  #   require 'palletjack/tool'
  #
  #   class MyTool < PalletJack::Tool
  #     def parse_options(parser)
  #       parser.on('-o DIR', '--output DIR',
  #                 'output directory',
  #                 String) {|dir| options[:output] = dir }
  #
  #       required_option :output
  #     end
  #   end
  #
  #   MyTool.run do
  #     jack['system'].each do |sys|
  #        config_dir :output, sys.name
  #        config_file :output, sys.name, "dump.yaml" do |file|
  #          file << sys.to_yaml
  #        end
  #     end
  #   end

  class Tool
    include Singleton

    # Run the +block+ given in the context of the tool singleton instance
    # as convenience for simple tools.
    #
    # More complex tools probably want to override parse_options to
    # add option parsing, and split functionality into multiple methods.
    #
    # Example:
    #
    #   MyTool.run { jack['system'].each {|sys| puts sys.to_yaml } }

    def self.run(&block)
      instance.instance_eval(&block)
    end

    # Initialize the singleton instance
    #
    # Default initialization will add options for --warehouse and --help
    # to the OptionParser, and set the banner to something useful.
    #
    # Any exceptions raised during option parsing will abort execution
    # with usage information.

    def initialize
      @parser = OptionParser.new
      @options = {}
      @option_checks = []

      @parser.banner = "Usage: #{$PROGRAM_NAME} -w <warehouse> [options]"
      @parser.separator ''
      @parser.on('-w DIR', '--warehouse DIR',
                 'warehouse directory', String) {|dir|
        @options[:warehouse] = dir }
      @parser.on_tail('-h', '--help', 'display usage information') {
        raise ArgumentError }

      parse_options(@parser)

      @parser.parse!
      @option_checks.each {|check| check.call }
    rescue
      abort(usage)
    end

    # Additional option parsing
    #
    # Implementations needing more options than the default --warehouse and
    # -- help should override this empty default

    def parse_options(parser)
    end

    # Require presence of one of the given options
    # Raises ArgumentError if none exist in options[]

    def required_option(*opts)
      @option_checks << lambda do
        raise ArgumentError unless opts.any? {|opt| options[opt]}
      end
    end

    # Require presence of no more than one of the given options
    # Raises ArgumentError if more than one exist in options[]

    def exclusive_options(*opts)
      @option_checks << lambda do
        raise ArgumentError if opts.count {|opt| options[opt]} > 1
      end
    end

    # Usage information from option parser
    #
    # Example:
    #
    #   abort(usage) unless options[:warehouse]

    def usage
      @parser.to_s
    end

    # Hash containing all parsed options.

    attr_reader :options

    # Return the PalletJack object for <tt>--warehouse</tt>
    # Aborts execution with usage message if the warehouse was
    # not specified.

    def jack
      abort(usage) unless options[:warehouse]
      @jack ||= PalletJack.new(options[:warehouse])
    end

    # Build a filesystem path from path components
    #
    # Symbols are looked up in the options dictionary.
    # All other types are converted to strings. The
    # resulting list is fed to File#join to produce a
    # local filesystem compliant path.
    #
    # Example:
    #   parser.on(...) {|dir| options[:output] = dir }
    #   ...
    #   config_path :output, 'subdir1'
    #   config_path :output, 'subdir2'

    def config_path(*path)
      File.join(path.map {|item|
                  case item
                  when Symbol
                    options.fetch(item)
                  else
                    item.to_s
                  end
                })
    end

    # :call-seq:
    # config_dir '/path/name'
    # config_dir :option, 'subdir', ...
    #
    # Creates a directory if it doesn't already exist.
    #
    # Uses config_path to construct the path.
    #
    # Example:
    #
    #   config_dir :output, system.name

    def config_dir(*path)
      Dir.mkdir(config_path(*path))
    rescue Errno::EEXIST
      nil
    end

    # :call-seq:
    # config_file "filename" {|file| ... }
    # config_file :option, 'fragment', 'base.ext' {|file| ... }
    # config_file ..., mode:0600 {|file| ...}
    #
    # Creates a configuration file, with default mode:0644
    # and calls the given block with the file as argument.
    #
    # Uses config_path to construct the path.
    #
    # Example:
    #
    #   config_file :output, system.name, 'dump.yaml' do |file|
    #     file << system.to_yaml
    #   end

    def config_file(*path, mode:0644, &block)
      File.open(config_path(*path),
                File::CREAT | File::TRUNC | File::WRONLY, mode) do |file|
        block.call(file)
      end
    end

    # Create a new pallet dir if needed

    def pallet_dir(kind, name)
      config_dir :warehouse, kind
      config_dir :warehouse, kind, name
    end

    # Write a new key box inside a pallet
    #
    # The block should return a hash representing the contents of the box.
    # All keys will be stringified, so we can use key: short forms for
    # declaration of the box contents.
    #
    # Example:
    #   pallet_box 'domain', :domain, 'dns' do
    #     { dns:{ ns:options[:soa_ns].split(',') } }
    #   end

    def pallet_box(kind, name, box, &block)
      config_file :warehouse, kind, name, "#{box}.yaml" do |box_file|
        box_file = block.call.deep_stringify_keys.to_yaml
      end
    end

    # Create links from a pallet to parents
    #
    # links contain key-value pairs <link_type>:[<parent_kind>, <parent_name>]
    #
    # If the link target is empty (e.g. <link_type>:[]), the link is removed.
    #
    # Example:
    #
    #   pallet_links 'system', :system, os:['os', :os], netinstall:[]

    def pallet_links(kind, name, links={})
      links.each do |link_type, parent|
        link_path = config_path(:warehouse, kind, name, link_type.to_s)

        begin
          File.delete(link_path)
        rescue Errno::ENOENT
          nil
        end
        unless parent.empty?
          parent_kind, parent_name = parent
          parent_path = config_path('..', '..', parent_kind, parent_name)

          File.symlink(parent_path, link_path)
        end
      end
    end

    # Return a string stating the Git provenance of a warehouse directory,
    # suitable for inclusion at the top of a generated configuration file,
    # with each line prefixed by +comment_char+.
    #
    # If <tt>options[:warehouse]</tt> points within a Git repository,
    # return a string stating its absolute path and active branch. If
    # +include_id+ is true, also include the commit ID of the branch's
    # HEAD.
    #
    # If Git information cannot be found for
    # <tt>options[:warehouse]</tt>, return a string stating its path
    # and print an error message on stderr.

    def git_header(tool_name, comment_char: '#', include_id: false)
      repo = Rugged::Repository.discover(options[:warehouse])
      workdir = repo.workdir
      branch = repo.head.name
      commit = repo.head.target_id

      header =
"#{comment_char}#{comment_char}
#{comment_char}#{comment_char} Automatically generated by #{tool_name} from
#{comment_char}#{comment_char} Repository: #{workdir}
#{comment_char}#{comment_char} Branch: #{branch}\n"
      if include_id
      then
        header +=
          "#{comment_char}#{comment_char} Commit ID: #{repo.head.target_id}\n"
      end
      header += "#{comment_char}#{comment_char}\n"
      return header
    rescue
      STDERR.puts "Error finding Git sourcing information: #{$!}"
      return "#{comment_char}#{comment_char}
#{comment_char}#{comment_char} Automatically generated by #{tool_name} from
#{comment_char}#{comment_char} Warehouse: #{warehouse_path}
#{comment_char}#{comment_char}\n"
    end
  end
end
