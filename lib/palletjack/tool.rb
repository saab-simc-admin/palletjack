require 'palletjack'
require 'fileutils'
require 'pathname'
require 'optparse'
require 'singleton'
require 'rugged'

module PalletJack
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
  #
  #     attr_reader :state
  #
  #     def process
  #       @state = {}
  #       jack.each(kind:'system') do |sys|
  #         @state[sys.name] = sys
  #       end
  #     end
  #
  #     def output
  #       @state.each do |name, data|
  #         config_dir :output, name
  #         config_file :output, name, "dump.yaml" do |file|
  #           file << data.to_yaml
  #         end
  #       end
  #     end
  #   end
  #
  #   if __FILE__ == $0
  #     MyTool.run
  #   end

  class Tool
    include Singleton

    # :call-seq:
    # run
    #
    # Main tool framework driver.
    #
    # Run the entire tool; setup, process and output. Actual tools
    # will want to use this function, while testing and other
    # activities that require poking around in internal state will
    # want to run the partial functions instead.
    #
    # Example:
    #
    #   if MyTool.standalone?(__FILE__)
    #     MyTool.run
    #   end

    def self.run(&block)
      instance.setup
      instance.process
      instance.output
    end

    # Predicate for detecting if we are being invoked as a standalone
    # tool, or loaded by e.g. a test framework.

    def self.standalone?(file)
      File::basename(file) == File::basename($0)
    end

    # Generate data in an internal format, saving it for later testing
    # or writing to disk by #output.
    #
    # Override this function in specific tool classes.
    #
    # Example:
    #
    #   class MyTool < PalletJack::Tool
    #     def process
    #       @systems = Set.new
    #       jack.each(kind:'system') do |s|
    #         @systems << s
    #       end
    #     end
    #   end

    def process
    end

    # Output data in its final format, probably to disk or stdout.
    #
    # Example:
    #
    #   class MyTool < PalletJack::Tool
    #     def output
    #       @systems.each do |s|
    #         puts s.name
    #       end
    #     end
    #   end

    def output
    end

    # Return the command line argument list to be used. Replace this
    # method when testing.

    def argv
      ARGV
    end

    # Set up the singleton instance
    #
    # Default setup will add options for --warehouse and --help to the
    # OptionParser, and set the banner to something useful.
    #
    # Any exceptions raised during option parsing will abort execution
    # with usage information.

    def setup
      @parser = OptionParser.new
      @options = {}
      @option_checks = []

      @parser.banner = "Usage: #{$PROGRAM_NAME} -w <warehouse> [options]"
      @parser.separator ''
      @parser.on('-w DIR', '--warehouse DIR',
                 'warehouse directory', String) {|dir|
        @options[:warehouse] = dir }
      @parser.on_tail('-V', '--version', 'display version information') {
        puts PalletJack::VERSION
        exit 0 }
      @parser.on_tail('-h', '--help', 'display usage information') {
        raise OptionParser::ParseError }

      parse_options(@parser)

      @parser.parse!(argv)
      @option_checks.each {|check| check.call }
    rescue OptionParser::ParseError => error
      if error.args.empty?
        abort(usage)
      else
        abort("#{error}\n\n#{usage}")
      end
    end

    # Additional option parsing
    #
    # The default instance initalization will add option parsing for
    # <tt>-w</tt>/<tt>--warehouse</tt> and <tt>-h</tt>/<tt>--help</tt>,
    # and a simple banner string.
    #
    # Implementations needing more options than the default, a more
    # informative banner, or requirement checks for parsed options should
    # override this empty method.
    #
    # Any exceptions raised will abort execution with usage information.
    #
    # Example:
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

    def parse_options(parser)
    end

    # Require the presence of one of the given options.
    #
    # Must not be called outside the scope of the parse_options method.
    #
    # Raises ArgumentError if none exist in options[]
    #
    # Example:
    #
    #   def parse_options(parser)
    #     ...
    #     required_option :output
    #   end

    def required_option(*opts)
      @option_checks << (lambda do
        raise OptionParser::ParseError unless opts.any? {|opt| options[opt]}
      end)
    end

    # Require the presence of no more than one of the given options.
    #
    # Must not be called outside the scope of the parse_options method.
    #
    # Raises ArgumentError if more than one exist in options[]
    #
    # Example:
    #
    #   def parse_options(parse)
    #     ...
    #     required_option :output_file, :output_stdout
    #     exclusive_options :output_file, :output_stdout
    #   end

    def exclusive_options(*opts)
      @option_checks << (lambda do
        raise OptionParser::ParseError if opts.count {|opt| options[opt]} > 1
      end)
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

    # Pallet containing all warehouse defined configuration options
    #
    # Configuration options for tools can be stored as pallets in
    # the warehouse:
    #
    #   _config
    #     |
    #     +-- MyTool
    #     |     |
    #     |     `-- somecfg.yaml

    def config
      @config ||= jack.fetch(kind: '_config',
                             name: self.class.to_s) rescue Hash.new
    end

    # Return the PalletJack object for <tt>--warehouse</tt>
    # Aborts execution with usage message if the warehouse was
    # not specified.

    def jack
      abort(usage) unless options[:warehouse]
      @jack ||= PalletJack.load(options[:warehouse])
    end

    # Build a filesystem path from path components
    #
    # Symbols are looked up in the options dictionary.
    # All components are converted to Pathname and concatenated.
    #
    # Example:
    #   parser.on(...) {|dir| options[:output] = dir }
    #   ...
    #   config_path :output, 'subdir1'
    #   config_path :output, 'subdir2'

    def config_path(*path)
      path.map { |item|
        case item
        when Pathname
          item
        when Symbol
          Pathname.new(options.fetch(item))
        else
          Pathname.new(item.to_s)
        end
      }.reduce(&:+)
    end

    # :call-seq:
    # config_dir '', 'path', 'name'
    # config_dir :option, 'subdir', ...
    #
    # Creates a directory if it doesn't already exist.
    #
    # Uses config_path to construct the path, so any symbols will
    # be looked up in the options hash.
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
    # config_file 'filename' {|file| ... }
    # config_file :option, 'fragment', 'base.ext' {|file| ... }
    # config_file ..., mode:0600 {|file| ...}
    #
    # Creates a temporary configuration file with an undefined name,
    # with default mode:0644, and calls the given block with the file
    # as argument. After the block has run, the file is atomically
    # renamed to the given destination file name. If any errors occur,
    # the temporary file is deleted without overwriting the
    # destination file.
    #
    # Uses config_path to construct the path, so any symbols will
    # be looked up in the options hash.
    #
    # N.B! If the file already exists, it will be overwritten!
    #
    # Example:
    #
    #   config_file :output, system.name, 'dump.yaml' do |file|
    #     file << system.to_yaml
    #   end

    def config_file(*path, mode: 0644, &block)
      filename = config_path(*path)
      begin
        temp_filename = "#{filename}.tmp.#{Process.pid}.#{rand(1_000_000)}"
        temp_file = File.new(temp_filename,
                             File::CREAT | File::EXCL | File::RDWR)
      rescue Errno::EEXIST
        retry
      end

      begin
        temp_file.flock(File::LOCK_EX)
        block.call(temp_file)
        temp_file.flush
        File.rename(temp_filename, filename)
      rescue
        File.unlink(temp_filename) rescue nil
        raise
      ensure
        temp_file.close
      end
    end

    # Create a new pallet directory inside the warehouse
    #
    # Uses config_dir to create the directory, so any symbols will
    # be looked up in the options hash.
    #
    # This is effectively a noop if the pallet already exists.
    #
    # Example:
    #
    #   pallet_dir 'system', :system_name

    def pallet_dir(kind, name)
      config_dir :warehouse, kind
      config_dir :warehouse, kind, name
    end

    # :call-seq:
    # pallet_box kind, name, box, 'key.path' => value, ...
    # pallet_box kind, name, box { { key: { path: value, ... } } }
    #
    # Write keys to a box file inside a pallet
    #
    # Any key.path assignments given as parameters, and the hash value
    # returned from a block will be merged into the named box file.
    #
    # All keys will be stringified, so we can use key: short forms for
    # declaration of the box contents.
    #
    # Uses config_file to create the file, so any symbols will
    # be looked up in the options hash, except for the box name.
    #
    # Example:
    #
    #   pallet_box 'domain', :domain, 'dns' do
    #     { dns:{ ns:options[:soa_ns].split(',') } }
    #   end
    #--
    # FIXME: Box I/O should probably be managed by PalletJack::Pallet,
    #        but that requires some redesign work.
    #++

    def pallet_box(kind, name, box, keyvalues = {}, &block)
      box_path = config_path(:warehouse, kind, name, "#{box}.yaml")
      contents = KVDAG::KeyPathHashProxy.new

      contents.merge! YAML::load_file(box_path) if box_path.file?
      keyvalues.each { |key, value| contents[key] = value }
      contents.merge! block.call if block_given?

      config_file box_path do |box_file|
        box_file << contents.deep_stringify_keys.to_yaml
      end
    end

    # Create links from a pallet to parents
    #
    # Uses config_path to construct paths within the warehouse, so any
    # symbols will be looked up in the options hash.
    #
    # +links+ is a hash containing +link_type+=>[+parent_kind+, +parent_name+]
    #
    # If the link target is empty (e.g. +link_type+=>[]), the link is removed.
    #
    # Example:
    #
    #   pallet_links 'system', :system, 'os'=>['os', :os], 'netinstall'=>[]

    def pallet_links(kind, name, links = {})
      links.each do |link_type, parent|
        link_base = config_path(:warehouse, kind, name)
        link_path = config_path(link_base, link_type)

        begin
          File.delete(link_path)
        rescue Errno::ENOENT
          nil
        end
        unless parent.empty?
          parent_kind, parent_name = parent
          parent_path = config_path(:warehouse, parent_kind, parent_name)

          File.symlink(parent_path.relative_path_from(link_base), link_path)
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
#{comment_char}#{comment_char} Warehouse: #{File.expand_path(options[:warehouse])}
#{comment_char}#{comment_char}\n"
    end
  end
end
