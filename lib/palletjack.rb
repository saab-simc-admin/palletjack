require 'active_support'
require 'yaml'
require 'kvdag'
require 'palletjack/version'
require 'palletjack/keytransformer'
require 'palletjack/pallet'

class PalletJack < KVDAG
  attr_reader :pallets
  attr_reader :keytrans_reader
  attr_reader :keytrans_writer

  def self.load(warehouse)
    new.load(warehouse)
  end

  def initialize
    super
    @pallets = Hash.new
  end

  def load(warehouse)
    @warehouse = File.expand_path(warehouse)
    key_transforms = YAML::load_file(File.join(@warehouse, "transforms.yaml"))
    @keytrans_reader = KeyTransformer::Reader.new(key_transforms)
    @keytrans_writer = KeyTransformer::Writer.new(key_transforms)

    Dir.foreach(@warehouse) do |kind|
      kindpath = File.join(@warehouse, kind)
      next unless File.directory?(kindpath) and kind !~ /^\.{1,2}$/

      Dir.foreach(kindpath) do |pallet|
        palletpath = File.join(kindpath, pallet)
        next unless File.directory?(palletpath) and pallet !~ /^\.{1,2}$/
        Pallet.new(self, palletpath)
      end
    end
    self
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
    vertices(filter)
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
