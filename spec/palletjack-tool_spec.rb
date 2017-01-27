require 'spec_helper'
require 'palletjack/tool'

describe PalletJack::Tool do
  it 'is a singleton class' do
    expect{ PalletJack::Tool.new }.to raise_error NoMethodError
    expect{ PalletJack::Tool.instance }.not_to raise_error
  end

  context 'without a command line' do
    before :each do
      allow(PalletJack::Tool.instance).to receive(:argv).and_return([])
    end

    it 'requires a warehouse' do
      class TestTool < PalletJack::Tool
        def process
          jack
        end
      end
      allow($stderr).to receive :write # Drop stderr output from #abort
      expect{ TestTool.run }.to raise_error SystemExit
    end
  end

  context 'with example warehouse' do
    before :each do
      class TestTool < PalletJack::Tool
        def options
          { warehouse: $EXAMPLE_WAREHOUSE }
        end
      end

      @tool = TestTool.instance
    end

    it 'can load a config pallet from a warehouse' do
      expect(@tool.config.kind).to match /^_config$/
      expect(@tool.config.name).to match TestTool.to_s
      expect(@tool.config['rspec.test_ok']).to eq 'true'
    end
  end
end
