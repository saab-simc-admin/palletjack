require 'spec_helper'

describe PalletJack do
  it 'has a version number' do
    expect(PalletJack::VERSION).not_to be nil
  end

  it 'requires a warehouse' do
    expect{ PalletJack.new('__INVALID__') }.to raise_error Errno::ENOENT
  end
end
