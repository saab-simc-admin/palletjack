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
  # The search is filtered by KVDAG::Vertex#match? expressions.
  #
  # Useful Pallet methods to match for include:
  #
  # kind:: the kind of pallet
  # name:: the filesystem +basename+ of the pallet

  def [](filter = {})
    @dag.vertices(filter)
  end

  # Fetch a single pallet from a PalletJack warehouse
  #
  # The search is filtered by KVDAG::Vertex#match? expressions.
  #
  # Useful Pallet methods to match for include:
  #
  # kind:: the kind of pallet
  # name:: the filesystem +basename+ of the pallet

  def fetch(filter = {})
    result = self[filter]

    if result.length != 1
      raise KeyError.new("#{options} matched #{result.length} pallets")
    end
    result.first
  end
end
