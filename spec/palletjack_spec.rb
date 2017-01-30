require 'spec_helper'

describe PalletJack do
  it 'has a version number' do
    expect(PalletJack::VERSION).not_to be nil
  end

  it 'can load a warehouse' do
    expect { PalletJack.load($EXAMPLE_WAREHOUSE) }.not_to raise_error
  end
end
