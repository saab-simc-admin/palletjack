require 'spec_helper'

describe 'Example warehouse' do
  it 'is a directory' do
    expect(File.directory?($EXAMPLE_WAREHOUSE)).to be true
  end

  it 'has a file named transforms.yaml' do
    transforms = File.join($EXAMPLE_WAREHOUSE, 'transforms.yaml')
    expect(File.exist?(transforms)).to be true
  end

  context 'when loaded' do
    before :all do
      @jack = PalletJack.load($EXAMPLE_WAREHOUSE)
    end

    it 'has pallets' do
      # because KVDAG currently does not respond to #empty?, we have to
      # use this instead, that compares against #count.
      expect(@jack).to have_at_least(1).item 
    end

    it 'has "system" kind of pallets' do
      expect(@jack[kind:'system']).not_to be_empty
    end

    context 'system "vmhost1"' do
      before :all do
        @sys = @jack.fetch(kind:'system', name:'vmhost1')
      end

      it 'has kind "system"' do
        expect(@sys.kind).to eq 'system'
      end

      it 'has name "vmhost1"' do
        expect(@sys.name).to eq 'vmhost1'
      end

      it 'has a "domain" parent' do
        expect(@sys.parents(kind:'domain')).not_to be_empty
      end

      it 'has an "ipv4_interface" child' do
        expect(@sys.children(kind:'ipv4_interface')).not_to be_empty
      end

      it 'has key net.dns.fqdn:"vmhost1.example.com"' do
        expect(@sys['net.dns.fqdn']).to eq 'vmhost1.example.com'
      end

      it 'has key system.role:"kvm-server"' do
        expect(@sys['system.role']).to include 'kvm-server'
      end
    end

    context 'system "__invalid__"' do
      it 'does not exist' do
        expect(@jack[kind:'system', name:'__invalid__']).to be_empty
      end
    end

    it 'has "domain" kind of pallets' do
      expect(@jack[kind:'domain']).not_to be_empty
    end

    it 'has "ipv4_interface" kind of pallets' do
      expect(@jack[kind:'ipv4_interface']).not_to be_empty
    end

    it 'does not have "__invalid__" kind of pallets' do
      expect(@jack[kind:'__invalid__']).to be_empty
    end
  end
end
