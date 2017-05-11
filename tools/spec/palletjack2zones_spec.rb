require 'spec_helper'
require 'tmpdir'
require 'rspec/collection_matchers'

require 'palletjack2zones'

describe 'palletjack2zones' do
  it 'requires an output directory' do
    @tool = PalletJack2Zones.instance
    allow(@tool).to receive(:argv).and_return([
      '-w', $EXAMPLE_WAREHOUSE
    ])
    allow($stderr).to receive(:write)
    expect{@tool.setup}.to raise_error SystemExit
  end

  it 'does not write server-specific configuration' do
    @tool = PalletJack2Zones.instance
    expect(@tool.zone_config('test')).to eq nil
  end

  context 'generates' do
    before :example do
      @tool = PalletJack2Zones.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE,
        '-o', Dir.tmpdir
      ])
      @tool.setup
      @tool.process
    end

    it 'a forward zone' do
      zones = @tool.instance_variable_get(:@forward_zones)
      expect(zones).to have_at_least(1).item
    end

    it 'a reverse zone' do
      zones = @tool.instance_variable_get(:@reverse_zones)
      expect(zones).to have_at_least(1).item
    end
  end

  context 'forward zone for example.com' do
    before :example do
      @tool = PalletJack2Zones.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE,
        '-o', Dir.tmpdir
      ])
      @tool.setup
      @tool.process
      @zone = @tool.instance_variable_get(:@forward_zones)['example.com']
    end

    it 'has a reasonable timestamp' do
      now = Time.now.utc.to_i
      expect(now - 10..now + 10).to cover(@zone.soa.serial)
    end

    it 'has the correct origin' do
      expect(@zone.origin).to eq('example.com.')
    end

    it 'has some records' do
      expect(@zone.records).to have_at_least(2).items
    end
  end

  context 'reverse zone for 192.168.0.0/24' do
    before :example do
      @tool = PalletJack2Zones.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE,
        '-o', Dir.tmpdir
      ])
      @tool.setup
      @tool.process
      @zone = @tool.instance_variable_get(:@reverse_zones)['0.168.192.in-addr.arpa']
    end

    it 'has a reasonable timestamp' do
      now = Time.now.utc.to_i
      expect(now - 10..now + 10).to cover(@zone.soa.serial)
    end

    it 'has the correct origin' do
      expect(@zone.origin).to eq('0.168.192.in-addr.arpa.')
    end

    it 'has some records' do
      expect(@zone.records).to have_at_least(2).items
    end
  end
end
