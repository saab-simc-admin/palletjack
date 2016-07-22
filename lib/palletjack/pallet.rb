class PalletJack
  class Pallet < KVDAG::Vertex
    def Pallet.new(jack, path)
      ppath, name = File.split(path)
      pppath, kind = File.split(ppath)

      jack.pallets[kind] ||= Hash.new
      jack.pallets[kind][name] || super
    end

    private :initialize
    def initialize(jack, path)
      @jack = jack
      @path = path
      ppath, name = File.split(path)
      pppath, kind = File.split(ppath)
      boxes = Array.new

      super(jack.dag, pallet:{kind => name})
      
      Dir.foreach(path) do |file|
        filepath = File.join(path, file)
        filestat = File.lstat(filepath)
        case
        when (filestat.file? and file =~ /\.yaml$/)
          merge!(YAML::load_file(filepath))
          boxes << file
        when filestat.symlink?
          link = File.readlink(filepath)
          lpath, lname = File.split(link)
          lppath, lkind = File.split(lpath)

          pallet = Pallet.new(jack, File.absolute_path(link, path))
          edge(pallet, pallet:{references:{lkind => lname}})
        end
      end
      merge!(pallet:{boxes: boxes})
      @jack.keytrans_writer.transform!(self)
      @jack.pallets[kind][name] = self
    end

    def inspect
      "#<%s:%x>" % [self.class, self.object_id, @path]
    end

    def to_yaml
      to_hash.to_yaml
    end
  end
end
