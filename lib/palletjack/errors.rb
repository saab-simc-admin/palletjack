require 'palletjack'

module PalletJack
  # Superclass for errors in Pallet Jack.
  class Error < RuntimeError
  end

  # A semantic error in the warehouse.
  #
  # Syntax errors will probably throw a Psych::SyntaxError at read
  # time instead.
  class WarehouseError < Error
  end
end
