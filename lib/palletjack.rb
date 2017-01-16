# External dependencies
require 'active_support'
require 'yaml'
require 'kvdag'

# Internal dependencies
require 'palletjack/version'
require 'palletjack/keytransformer'
require 'palletjack/pallet'
require 'traceable'

class PalletJack < KVDAG
  attr_reader :warehouse

  # Create and load a PalletJack warehouse, and all its pallets

  def self.load(warehouse)
    new.load(warehouse)
  end

  def initialize
    super
    @pallets = Hash.new
  end

  # Load a PalletJack warehouse, and all its pallets

  def load(warehouse)
    @warehouse = File.expand_path(warehouse)
    key_transforms = TraceableYAML::load_file(File.join(@warehouse, 'transforms.yaml'), 'transforms.yaml')
    @keytrans_reader = KeyTransformer::Reader.new(key_transforms)
    @keytrans_writer = KeyTransformer::Writer.new(key_transforms)

    Dir.foreach(@warehouse) do |kind|
      kindpath = File.join(@warehouse, kind)
      next unless File.directory?(kindpath) and kind !~ /^\.{1,2}$/

      Dir.foreach(kindpath) do |pallet|
        palletpath = File.join(kindpath, pallet)
        next unless File.directory?(palletpath) and pallet !~ /^\.{1,2}$/
        pallet(kind, pallet)
      end
    end

    # Apply transforms in reverse DAG order, parents before children
    sort.reverse.each do |pallet|
      @keytrans_writer.transform! pallet
    end

    self
  end

  # Return a named pallet from the warehouse
  #
  # If the pallet is not yet loaded, it will be.
  #
  # Raises RuntimeError if the warehouse is not loaded.
  # Raises Errno::ENOENT if the pallet can't be loaded.

  def pallet(kind, name)
    raise "warehouse is not loaded" unless @warehouse

    identity = Pallet::Identity.new(self, File.join(kind, name))
    @pallets[identity.path] ||= Pallet.load(self, identity)
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
      raise KeyError.new("#{filter} matched #{result.length} pallets")
    end
    result.first
  end
end
