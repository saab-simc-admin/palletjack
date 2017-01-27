require 'spec_helper'

describe PalletJack do
  it 'has a version number' do
    expect(PalletJack::VERSION).not_to be nil
  end

  it 'requires a warehouse' do
    expect{ PalletJack.load('__INVALID__') }.to raise_error Errno::ENOENT
  end

  it 'requires a warehouse to load a pallet' do
    expect{
      PalletJack.new.pallet('domain', 'example.com')
    }.to raise_error RuntimeError
  end
  
  context 'with a loaded warehouse' do
    before :context do
      @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
    end
    
    it 'can fetch a unique pallet' do
      expect(
        @jack.fetch(kind: 'domain', name: 'example.com')
      ).to be_a PalletJack::Pallet
    end
    
    it 'raises a KeyError when fetching a non-existent pallet' do
      expect{
        @jack.fetch(kind: '__invalid__')
      }.to raise_error KeyError
    end
    
    it 'raises a KeyError when fetching more than one pallet at once' do
      expect{
        @jack.fetch
      }.to raise_error KeyError
    end
  end
end
