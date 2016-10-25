require 'active_support'
require 'yaml'
require 'kvdag'
require 'palletjack/version'
require 'palletjack/keytransformer'
require 'palletjack/pallet'

class PalletJack
  attr_reader :pallets
  attr_reader :dag
  attr_reader :keytrans_reader
  attr_reader :keytrans_writer

  private :initialize
  def initialize(warehouse)
    @warehouse = File.expand_path(warehouse)
    key_transforms = YAML::load_file(File.join(@warehouse, "transforms.yaml"))
    @keytrans_reader = KeyTransformer::Reader.new(key_transforms)
    @keytrans_writer = KeyTransformer::Writer.new(key_transforms)
    @pallets = Hash.new
    @dag = KVDAG.new

    Dir.foreach(@warehouse) do |kind|
      kindpath = File.join(@warehouse, kind)
      next unless File.directory?(kindpath) and kind !~ /^\.{1,2}$/

      Dir.foreach(kindpath) do |pallet|
        palletpath = File.join(kindpath, pallet)
        next unless File.directory?(palletpath) and pallet !~ /^\.{1,2}$/
        Pallet.new(self, palletpath)
      end
    end
  end

  # Search for pallets in a PalletJack warehouse
  #
  # :call-seq:
  #   [kind]                        -> set of pallets
  #   [kind, name: pallet_name]     -> set of pallets
  #   [kind, with_all:{ matches }]  -> set of pallets
  #   [kind, with_any:{ matches }]  -> set of pallets
  #   [kind, with_none:{ matches }] -> set of pallets
  #
  # Return all pallets of +kind+, optionally restricting by
  # keypath matches.
  #
  # +pallet_name+ is the filesystem +basename+ for the pallet.
  #
  # +matches+ should be a hash with "key.path" strings as keys,
  # and either string or regexp values to match against.

  def [](kind, options = {})
    match_enumerator = {
      :with_all  => :all?,
      :with_any  => :any?,
      :with_none => :none?
    }
    result = Set.new

    case
    when options.empty?
      result += @pallets[kind].values
    when options[:name]
      if p = @pallets[kind][options[:name]]
        result << p
      end
    else
      match_enumerator.keys.each do |tag|
        if options[tag]
          @pallets[kind].each do |_, pallet|
            if options[tag].send(match_enumerator[tag]) do |key, value|
                case value
                when Regexp
                  pallet[key] =~ value
                else
                  pallet[key].to_s == value.to_s
                end
              end
            then
              result << pallet
            end
          end
        end
      end
    end

    result
  end

  # Fetch a single pallet from a PalletJack warehouse
  #
  # :call-seq:
  #   fetch(kind)                        -> pallet or KeyError
  #   fetch(kind, name: name)            -> pallet or KeyError
  #   fetch(kind, with_all:{ matches })  -> pallet or KeyError
  #   fetch(kind, with_any:{ matches })  -> pallet or KeyError
  #   fetch(kind, with_none:{ matches }) -> pallet or KeyError
  #
  # Return exactly one pallet of +kind+, optionally restricting by
  # keypath matches.
  #
  # Raise a KeyError if there is more or less than one match.
  #
  # +matches+ should be a hash with "key.path" strings as keys,
  # and either string or regexp values to match against.
  #

  def fetch(kind, options = {})
    result = self[kind, options]
    if result.length != 1 then
      raise KeyError.new("\"#{kind}\", #{options} matched #{result.length} pallets")
    end

    result.first
  end
end
