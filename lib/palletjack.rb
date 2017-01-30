require 'palletjack/version.rb'
require 'palletjack/warehouse.rb'

module PalletJack
  def self.load(warehouse)
    Warehouse.load(warehouse)
  end
end
