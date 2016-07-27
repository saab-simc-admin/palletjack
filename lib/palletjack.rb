require 'active_support'
require 'yaml'
require 'kvdag'
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

  def [](kind, options = {})
    result = Set.new
    case
    when options[:with_all]
      @pallets[kind].each do |name, pallet|
        result << pallet if options[:with_all].all? do |key, value|
          case value
            when Regexp
              pallet[key] =~ value
            else
              pallet[key].to_s == value.to_s
          end
        end
      end
    when options[:with_any]
      @pallets[kind].each do |name, pallet|
        result << pallet if options[:with_any].any? do |key, value|
          case value
            when Regexp
              pallet[key] =~ value
            else
              pallet[key].to_s == value.to_s
          end
        end
      end
    when options[:with_none]
      @pallets[kind].each do |name, pallet|
        result << pallet if options[:with_none].none? do |key, value|
          case value
            when Regexp
              pallet[key] =~ value
            else
              pallet[key].to_s == value.to_s
          end
        end
      end
    when options[:name]
      p = @pallets[kind][options[:name]]
      result << p if p
    else
      @pallets[kind].each do |name, pallet|
        result << pallet
      end
    end
    result
  end
end
