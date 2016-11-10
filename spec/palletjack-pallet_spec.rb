require 'spec_helper'
require 'rspec_structure_matcher'

describe PalletJack::Pallet do
  before :context do
    @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
  end
  
  it 'can load contents of a pallet' do
    expect {
      PalletJack::Pallet.load(@jack, 'domain', 'example.com')
    }.not_to raise_error
  end
  
  it 'cannot load contents of a non-existent pallet' do
    expect {
      PalletJack::Pallet.load(@jack, '__invalid__', '__no_such__')
    }.to raise_error Errno::ENOENT
  end
  
  context 'a loaded pallet' do
    before :context do
      @pallet = PalletJack::Pallet.load(@jack, 'domain', 'example.com')
    end
    
    it 'has a kind' do
      expect(@pallet.kind).to match 'domain'
    end
    
    it 'has a name' do
      expect(@pallet.name).to match 'example.com'
    end
    
    it 'serializes into YAML of its key contents' do
      pallet_hash = @pallet.to_hash
      yaml_hash = YAML::load(@pallet.to_yaml)
      expect(yaml_hash).to have_structure pallet_hash
    end
  end
end
