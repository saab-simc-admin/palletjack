require 'spec_helper'
require 'tmpdir'

load 'palletjack2salt'

describe 'palletjack2salt' do
  context 'generated global configuration' do
    before :each do
      @tool = PalletJack2Salt.instance
      allow(@tool).to receive(:argv).and_return(
        ['-w', $EXAMPLE_WAREHOUSE,
         '-g', Dir.tmpdir]) # Won't actually be written to, but needs
                            # to exist to make the command line option
                            # parser happy
      @tool.setup
      @tool.process
      @global = @tool.salt_config[:global]
    end

    it 'contains configuration for os images' do
      os_pillar = { 'host' => { 'kickstart' => Hash,
                                'pxelinux' => Hash },
                    'system' => Hash }
      @tool.jack.each(kind:'os') do |os|
        expect(@global['os'][os.name]).to have_structure(os_pillar)
      end
    end

    it 'contains configuration for netinstall configurations' do
      ni_pillar = { 'host' => { 'kickstart' => Hash,
                                'pxelinux' => Hash },
                    'system' => Hash }
      @tool.jack.each(kind:'netinstall') do |ni|
        expect(@global['netinstall'][ni.name]).to have_structure(ni_pillar)
      end
    end
  end

  context 'generated per-minion configuration' do
    before :each do
      @tool = PalletJack2Salt.instance
      allow(@tool).to receive(:argv).and_return(
        ['-w', $EXAMPLE_WAREHOUSE,
         '-m', Dir.tmpdir]) # Won't actually be written to, but needs
                            # to exist to make the command line option
                            # parser happy
      @tool.setup
      @tool.process
      @minion = @tool.salt_config[:minion]
    end

    it 'contains configuration for some known clients' do
      basic_structure = { 'palletjack' => Hash }
      expect(@minion['vmhost1.example.com']).to have_structure(basic_structure)
      expect(@minion['testvm.example.com']).to have_structure(basic_structure)
    end

    it 'contains configuration for all clients in the warehouse' do
      minions = {}
      @tool.jack.each(kind:'system') do |system|
        minions[system['net.dns.fqdn']] = { 'palletjack' => Hash }
      end
      expect(@minion).to have_structure(minions)
    end

    it 'contains network configuration' do
      interfaces =
      {
        'em1' =>
        {
          '192.168.0.1' =>
          {
            'net' =>
            {
              'ipv4' =>
              {
                'gateway' => '192.168.0.1',
                'prefixlen' => '24',
                'cidr' => '192.168.0.0/24',
                'address' => '192.168.0.1'
              },
              'layer2' =>
              {
                'address' => '14:18:77:ab:cd:ef',
                'name' => 'em1'
              }
            }
          }
        }
      }
      expect(@minion['vmhost1.example.com']['palletjack']['ipv4_interfaces']).to have_structure(interfaces)
    end

    it 'contains system configuration' do
      system =
      {
        'os' => 'CentOS-7.3.1611-x86_64',
        'architecture' => 'x86_64',
        'role' => ['kvm-server', 'ssh-server'],
        'name' => 'vmhost1'
      }
      expect(@minion['vmhost1.example.com']['palletjack']['system']).to have_structure(system)
    end

    context 'contains service configuration' do
      it 'for syslog' do
        syslog_config =
        [
          {
            'address' => 'syslog-archive.example.com',
            'port' => '514',
            'protocol' => 'udp'
          },
          {
            'address' => 'logstash.example.com',
            'port' => '5514',
            'protocol' => 'tcp'
          }
        ]
        0.upto(syslog_config.length) do |i|
          expect(@minion['vmhost1.example.com']['palletjack']['service']['syslog'][i]).to have_structure(syslog_config[i])
        end
      end

      it 'for zabbix' do
        zabbix_config =
        [
          { 'address' => 'zabbix.example.com' },
          {
            'address' => 'zabbix2',
            'port' => '10051'
          }
        ]
        0.upto(zabbix_config.length) do |i|
          expect(@minion['vmhost1.example.com']['palletjack']['service']['zabbix'][i]).to have_structure(zabbix_config[i])
        end
      end
    end
  end
end
