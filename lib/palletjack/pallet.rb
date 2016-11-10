class PalletJack
  # PalletJack managed pallet of key boxes inside a warehouse.
  class Pallet < KVDAG::Vertex

    attr_reader :name
    attr_reader :kind

    # N.B: A pallet should never be loaded manually; use
    # +PalletJack.load+ to initialize a complete warehouse.
    #
    # [+jack+] PalletJack that will manage this pallet.
    # [+kind+] Kind of pallet.
    # [+name+] Name of pallet.
    #
    # Creates and loads a new PalletJack warehouse pallet.

    def self.load(jack, kind, name)
      path = File.join(jack.warehouse, kind, name)
      new(jack, pallet:{kind => name}).load(path)
    end

    # N.B: A pallet should never be loaded manually; use
    # +PalletJack::load+ to initialize a complete warehouse.
    #
    # [+path+] Filesystem path to pallet data.
    #
    # Loads and merges all YAML files in +path+ into this Vertex.
    #
    # Follows all symlinks in +path+ and creates edges towards
    # the pallet located in the symlink target.

    def load(path)
      ppath, @name = File.split(path)
      _, @kind = File.split(ppath)
      boxes = Array.new

      Dir.foreach(path) do |file|
        next if file[0] == '.'
        filepath = File.join(path, file)
        filestat = File.lstat(filepath)
        case
        when (filestat.file? and file =~ /\.yaml$/)
          merge!(YAML::load_file(filepath))
          boxes << file
        when filestat.symlink?
          link = File.readlink(filepath)
          _, lname = File.split(link)
          ppath, pname = File.split(File.absolute_path(link, path))
          _, pkind = File.split(ppath)

          pallet = jack.pallet(pkind, pname)
          edge(pallet, pallet:{references:{file => lname}})
        end
      end
      merge!(pallet:{boxes: boxes})
      jack.keytrans_writer.transform!(self)

      self
    end

    def inspect
      "#<%s:%x>" % [self.class, self.object_id, @path]
    end

    # Override standard to_yaml serialization, because pallet objects
    # are ephemeral by nature. The natural serialization is that of
    # their to_hash analogue.
    def to_yaml
      to_hash.to_yaml
    end

    private

    alias :jack :dag
  end
end
