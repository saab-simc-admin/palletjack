require 'palletjack/pallet/identity'
require 'traceable'

module PalletJack
  # PalletJack managed pallet of key boxes inside a warehouse.
  class Pallet < KVDAG::Vertex
    # N.B: A pallet should never be loaded manually; use
    # +PalletJack.load+ to initialize a complete warehouse.
    #
    # [+jack+] PalletJack that will manage this pallet.
    # [+identity+] Identity of the pallet to be loaded.
    #
    # Creates and loads a new PalletJack warehouse pallet.

    def self.load(jack, identity)
      new(jack).load(identity)
    end

    # N.B: A pallet should never be loaded manually; use
    # +PalletJack::load+ to initialize a complete warehouse.
    #
    # [+identity+] Identity of the pallet to be loaded.
    #
    # Loads and merges all YAML files in +path+ into this Vertex.
    #
    # Follows all symlinks in +path+ and creates edges towards
    # the pallet located in the symlink target.

    def load(identity)
      @identity = identity
      boxes = Array.new
      path = @identity.path

      Dir.foreach(path) do |file|
        next if file[0] == '.' # skip dot.files

        filepath = File.join(path, file)
        filestat = File.lstat(filepath)
        case
        when (filestat.file? and file =~ /\.yaml$/)
          merge!(TraceableYAML::load_file(filepath,
                   filepath.sub(@identity.warehouse, '')[1..-1]))
          boxes << file
        when filestat.symlink?
          link = File.readlink(filepath)
          target = File.expand_path(link, path)
          unless File.exist? target
            raise Errno::ENOENT.new "broken symlink #{filepath} -> #{link}"
          end
          link_id = Identity.new(jack, target)

          pallet = jack.pallet(link_id.kind, link_id.full_name)
          edge(pallet, pallet: {references: {file => link_id.full_name}})
        when filestat.directory?
          child = jack.pallet(kind, File.join(name, file))
          child.edge(self, pallet: {references: {_parent: full_name}})
        end
      end
      merge!(pallet: {kind => name, boxes: boxes})

      self
    end

    def inspect
      '#<%s:%x>' % [self.class, self.object_id, @path]
    end

    # Override standard to_yaml serialization, because pallet objects
    # are ephemeral by nature. The natural serialization is that of
    # their to_hash analogue.

    def to_yaml
      to_hash.to_yaml
    end

    # The kind of this pallet

    def kind
      @identity.kind
    end

    # The leaf name of this pallet in its hierarchy

    def leaf_name
      @identity.leaf_name
    end

    # Compatibility alias name is the leaf name

    alias name leaf_name

    # The full hierarchical name of this pallet

    def full_name
      @identity.full_name
    end

    # The full name of the hierarchical parent for this pallet,
    # or nil if there is no parent.

    def parent_name
      @identity.parent_name
    end

    private

    alias :jack :dag
  end
end
