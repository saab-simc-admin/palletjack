require 'spec_helper'
require 'rspec_structure_matcher'
require 'traceable'

describe PalletJack::Pallet do
  before :example do
    @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
  end

  it 'can load contents of a pallet' do
    expect {
      path = File.join('domain', 'example.com')
      identity = PalletJack::Pallet::Identity.new(@jack, path)
      PalletJack::Pallet.load(@jack, identity)
    }.not_to raise_error
  end

  it 'cannot load contents of a non-existent pallet' do
    expect {
      path = File.join('__invalid__', '__no_such__')
      identity = PalletJack::Pallet::Identity.new(@jack, path)
      PalletJack::Pallet.load(@jack, identity)
    }.to raise_error Errno::ENOENT
  end

  context 'a loaded pallet' do
    before :context do
      @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
      path = File.join('domain', 'example.com')
      identity = PalletJack::Pallet::Identity.new(@jack, path)
      @pallet = PalletJack::Pallet.load(@jack, identity)
    end

    it 'has a kind' do
      expect(@pallet.kind).to match 'domain'
    end

    it 'has a name' do
      expect(@pallet.name).to match 'example.com'
    end

    it 'serializes into YAML of its key contents' do
      pallet_hash = @pallet.to_hash
      yaml_hash = TraceableYAML::parse(@pallet.to_yaml, @pallet.name)

      expect(yaml_hash).to have_structure pallet_hash
    end
  end

  context 'value sources' do
    before :context do
      @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
      @pallet = @jack.fetch(kind:'domain', name:'example.com')
    end

    it 'exist for loaded values' do
      expect(@pallet['net.dns.soa-ns'].file).to eq "domain/example.com/dns.yaml"
      expect(@pallet['net.dns.soa-ns'].line).to be_an Integer
      expect(@pallet['net.dns.soa-ns'].line).not_to be 0
      expect(@pallet['net.dns.soa-ns'].column).to be_an Integer
      expect(@pallet['net.dns.soa-ns'].column).not_to be 0
      expect(@pallet['net.dns.soa-ns'].byte).to be_an Integer
      expect(@pallet['net.dns.soa-ns'].byte).not_to be 0
    end

    it 'exist for transformed values' do
      expect(@pallet['net.dns.domain'].file).to eq "transforms.yaml"
      expect(@pallet['net.dns.domain'].line).to be_an Integer
      expect(@pallet['net.dns.domain'].line).not_to be 0
      expect(@pallet['net.dns.domain'].column).to be_an Integer
      expect(@pallet['net.dns.domain'].column).not_to be 0
      expect(@pallet['net.dns.domain'].byte).to be_an Integer
      expect(@pallet['net.dns.domain'].byte).not_to be 0
    end
  end
end
