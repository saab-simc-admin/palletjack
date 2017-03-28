require 'spec_helper'
require 'tmpdir'
require 'rspec/collection_matchers'

load 'palletjack2unbound'

describe 'palletjack2unbound' do
  it 'requires a service name' do
    @tool = PalletJack2Unbound.instance
    allow(@tool).to receive(:argv).and_return([
      '-w', $EXAMPLE_WAREHOUSE,
      '-o', Dir.tmpdir
    ])
    allow($stderr).to receive(:write)
    expect{@tool.setup}.to raise_error SystemExit
  end

  it 'requires an output directory' do
    @tool = PalletJack2Unbound.instance
    allow(@tool).to receive(:argv).and_return([
      '-w', $EXAMPLE_WAREHOUSE,
      '-s', 'example-com'
    ])
    allow($stderr).to receive(:write)
    expect{@tool.setup}.to raise_error SystemExit
  end

  context 'generated service configuration' do
    before :example do
      @tool = PalletJack2Unbound.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE,
        '-o', Dir.tmpdir,
        '-s', 'example-com'
      ])
      @tool.setup
      @tool.process_service_config
      unbound_config = @tool.instance_variable_get(:@unbound_config)
      service_config = unbound_config.instance_variable_get(:@service_config)
      @config_options = service_config['service.unbound.server']
    end

    it 'declares a listening interface' do
      expect(@config_options).to include({'interface' => String})
    end

    it 'declares access control' do
      expect(@config_options).to include({'access-control' => String})
    end

    it 'declares a private domain' do
      expect(@config_options).to include({'private-domain' => String})
    end

    it 'declares a private address space' do
      expect(@config_options).to include({'private-address' => String})
    end
  end

  context 'generated zone configuration' do
    before :example do
      @tool = PalletJack2Unbound.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE,
        '-o', Dir.tmpdir,
        '-s', 'example-com'
      ])
      @tool.setup
      @tool.process_stub_zones
      @stub_zones = @tool.instance_variable_get(:@stub_zones)
    end

    it 'has at least two stub zones' do
      expect(@stub_zones).to have_at_least(2).items
    end

    context 'for a stub zone' do
      it 'has a zone name' do
        expect(@stub_zones.first.instance_variable_get(:@zone)).to be_a String
      end

      it 'has a name server addresses' do
        expect(
          @stub_zones.first.instance_variable_get(:@stub_addrs)
        ).to have_at_least(1).item
      end

      context 'in in-addr.arpa for RFC1918 address space' do
        it 'is declared "transparent"' do
          expect(
            @stub_zones.select { |stub|
              # Let's hope the examples stay in this RFC1918 space
              stub.instance_variable_get(:@zone) =~ /\.168\.192\.in-addr\.arpa/
            }.all? { |stub|
              stub.instance_variable_get(:@transparent)
            }
          ).to be true
        end
      end

      context 'outside in-addr.arpa for RFC1918 address space' do
        it 'is not declared "transparent"' do
          expect(
            @stub_zones.reject { |stub|
              # Let's hope the examples stay in this RFC1918 space
              stub.instance_variable_get(:@zone) =~ /\.168\.192\.in-addr\.arpa/
            }.none? { |stub|
              instance_variable_get(:@transparent)
            }
          ).to be true
        end
      end
    end
  end
end
