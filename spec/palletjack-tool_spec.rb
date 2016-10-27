require 'spec_helper'
require 'palletjack/tool'

describe PalletJack::Tool do
  it 'is a singleton class' do
    expect{ PalletJack::Tool.new }.to raise_error NoMethodError
    expect{ PalletJack::Tool.instance }.not_to raise_error
  end

  it 'can run a block in its instance context' do
    expect(PalletJack::Tool.run { self.class }).to be PalletJack::Tool
  end

  it 'keeps state between invocations' do
    PalletJack::Tool.run { @__rspec__remember_me = true }
    expect(PalletJack::Tool.run { @__rspec__remember_me }).to be true
  end

  it 'requires a warehouse' do
    allow($stderr).to receive :write # Drop stderr output from #abort
    expect{ PalletJack::Tool.run { jack } }.to raise_error SystemExit
  end

  context 'with example warehouse' do
    before :each do
      class TestTool < PalletJack::Tool
        def parse_options(_)
          options[:warehouse] = $EXAMPLE_WAREHOUSE
        end
      end

      @tool = TestTool.instance
    end

    it 'can load a config pallet from a warehouse' do
      expect(@tool.config.kind).to match /^_config$/
      expect(@tool.config.name).to match TestTool.to_s
      expect(@tool.config['rspec.test_ok']).to be true
    end
  end
end
