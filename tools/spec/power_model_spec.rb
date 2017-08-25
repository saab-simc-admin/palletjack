require 'spec_helper'

load 'power_model'

describe 'power_model' do
  it 'initializes the model to zero' do
    @tool = PowerModel.instance
    allow(@tool).to receive(:argv).and_return([
      '-w', $EXAMPLE_WAREHOUSE
    ])

    @tool.setup
    @tool.initialize_model

    expect(@tool.power_model['ups']['ups1']).to eq({
      'capacity' => 50_000,
      'load' => 0
    })
    expect(@tool.power_model['chassis']).to eq({})
    ['rack', 'room', 'building'].each do |type|
      expect(@tool.power_model[type]).to have_at_least(1).item
      @tool.power_model[type].values do |e|
        expect(e).to eq({
          'capacity' => 0,
          'load' => 0
        })
      end
    end
  end

  context 'computed values' do
    before :example do
      @tool = PowerModel.instance
      allow(@tool).to receive(:argv).and_return([
        '-w', $EXAMPLE_WAREHOUSE
      ])

      @tool.setup
      @tool.process
    end

    it 'reads chassis max load' do
      expect(@tool.power_model['chassis']['Example:FastServer-128:1234ABCD']).to eq(1_000)
    end

    it 'sums physical hierarchy loads' do
      expect(@tool.power_model['rack']['1-A-2']['load']).to eq(1_000)
      expect(@tool.power_model['room']['server-room-1']['load']).to eq(1_000)
      expect(@tool.power_model['building']['1']['load']).to eq(1_000)
    end

    it 'sums UPS loads' do
      expect(@tool.power_model['ups']['ups1']['load']).to eq(1_000)
    end

    it 'calculates load percentages' do
      expect(@tool.load_percent('ups1')).to eq(2)
    end
  end
end
