require 'palletjack/version.rb'
require 'palletjack/warehouse.rb'

# Top level namespace for all PalletJack related classes
module PalletJack
  def self.load(warehouse)
    Warehouse.load(warehouse)
  end
end
