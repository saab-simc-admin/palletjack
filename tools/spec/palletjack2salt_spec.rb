require 'spec_helper'
require 'tmpdir'

load "palletjack2salt"

describe 'palletjack2salt' do
  context 'generated configuration' do
    before :all do
      class PalletJack2Salt
        def argv
          ["-w", $EXAMPLE_WAREHOUSE,
           "-o", Dir.tmpdir] # Won't actually be written to, but needs
                             # to exist to make the command line
                             # option parser happy
        end
      end

      @tool = PalletJack2Salt.instance
      @tool.process
    end

    it 'contains configuration for some known clients' do
      basic_structure = { 'palletjack' => Hash }
      expect(@tool.salt_config['vmhost1.example.com']).to have_structure(basic_structure)
      expect(@tool.salt_config['testvm.example.com']).to have_structure(basic_structure)
    end

    it 'contains configuration for all clients in the warehouse' do
      minions = {}
      @tool.jack.each(kind:'system') do |system|
        minions[system['net.dns.fqdn']] = { 'palletjack' => Hash }
      end
      expect(@tool.salt_config).to have_structure(minions)
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
      expect(@tool.salt_config['vmhost1.example.com']['palletjack']['ipv4_interfaces']).to have_structure(interfaces)
    end

    it 'contains system configuration' do
      system =
      {
        'os' => 'CentOS-7.2.1511-x86_64',
        'architecture' => 'x86_64',
        'role' => ['kvm-server', 'ssh-server'],
        'name' => 'vmhost1'
      }
      expect(@tool.salt_config['vmhost1.example.com']['palletjack']['system']).to have_structure(system)
    end

    context 'contains service configuration' do
      it 'for syslog' do
        syslog_config =
        [
          {
            'address' => 'syslog-archive.example.com',
            'port' => 514,
            'protocol' => 'udp'
          },
          {
            'address' => 'logstash.example.com',
            'port' => 5514,
            'protocol' => 'tcp'
          }
        ]
        0.upto(syslog_config.length) do |i|
          expect(@tool.salt_config['vmhost1.example.com']['palletjack']['service']['syslog'][i]).to have_structure(syslog_config[i])
        end
      end

      it 'for zabbix' do
        zabbix_config =
        [
          { 'address' => 'zabbix.example.com' },
          {
            'address' => 'zabbix2',
            'port' => 10051
          }
        ]
        0.upto(zabbix_config.length) do |i|
          expect(@tool.salt_config['vmhost1.example.com']['palletjack']['service']['zabbix'][i]).to have_structure(zabbix_config[i])
        end
      end
    end
  end
end
