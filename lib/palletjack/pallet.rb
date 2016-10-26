class PalletJack
  # PalletJack managed pallet of key boxes inside a warehouse.
  class Pallet < KVDAG::Vertex

    attr_reader :name
    attr_reader :kind

    # N.B: A pallet should never be created manually; use
    # +PalletJack::new+ to initialize a complete warehouse.
    #
    # [+jack+] PalletJack that will manage this pallet.
    # [+path+] Filesystem path to pallet data.
    #
    # Create PalletJack managed singletonish pallet.
    #
    # Use relative path inside of warehouse as kind/name for this
    # pallet, and make a singletonish object for that key.

    def Pallet.new(jack, path) #:doc:
      ppath, name = File.split(path)
      _, kind = File.split(ppath)

      jack.pallets[kind] ||= Hash.new
      jack.pallets[kind][name] || super
    end

    # N.B: A pallet should never be created manually; use
    # +PalletJack::new+ to initialize a complete warehouse.
    #
    # [+jack+] PalletJack that will manage this pallet.
    # [+path+] Filesystem path to pallet data.
    #
    # Loads and merges all YAML files in +path+ into this Vertex.
    #
    # Follows all symlinks in +path+ and creates edges towards
    # the pallet located in the symlink target.

    private :initialize
    def initialize(jack, path) #:notnew:
      @jack = jack
      @path = path
      ppath, @name = File.split(path)
      _, @kind = File.split(ppath)
      boxes = Array.new

      super(jack, pallet:{@kind => @name})

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

          pallet = Pallet.new(jack, File.absolute_path(link, path))
          edge(pallet, pallet:{references:{file => lname}})
        end
      end
      merge!(pallet:{boxes: boxes})
      @jack.keytrans_writer.transform!(self)
      @jack.pallets[@kind][@name] = self
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
  end
end
