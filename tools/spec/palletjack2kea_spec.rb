require 'spec_helper'
require 'rspec/collection_matchers'

load "palletjack2kea"

describe 'palletjack2kea' do
  context 'generated configuration' do
    before :all do
      class PalletJack2Kea
        def argv
          ["-w", $EXAMPLE_WAREHOUSE,
           "-s", "dhcp-server-example-net"]
        end
      end

      @tool = PalletJack2Kea.instance
      @tool.process
    end

    it 'configures a server' do
      server_config =
      {
        'Dhcp4' => {
          'interfaces-config' => {
            'interfaces' => lambda { |value|
                              value.is_a?(Array) &&
                              value.all? { |v| v.is_a?(String) }
                            }
          },
          'lease-database' => {
            'type' => 'memfile'
          },
          'valid-lifetime' => Integer,
          'subnet4' => Array
        }
      }

      expect(@tool.kea_config).to have_structure(server_config)
    end

    it 'configures a subnet' do
      subnet_config =
      {
        'subnet' => String,
        'reservations' => Array,
        'option-data' => Array,
        'next-server' => /\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/
      }

      expect(@tool.kea_config['Dhcp4']['subnet4']).to have(1).items
      expect(@tool.kea_config['Dhcp4']['subnet4'].first).to have_structure(subnet_config)
    end

    it 'reserves vmhost1.example.com' do
      vmhost1_config =
      {
        'hw-address' => '14:18:77:ab:cd:ef',
        'ip-address' => '192.168.0.1',
        'hostname' => 'vmhost1.example.com',
        'option-data' => [
          {
            'code' => 15,
            'name' => 'domain-name',
            'space' => 'dhcp4',
            'csv-format' => true,
            'data' => 'example.com'
          }
        ]
      }

      reservation = @tool.kea_config['Dhcp4']['subnet4'].first['reservations'].find { |r|
        r['hostname'] == 'vmhost1.example.com'
      }
      expect(reservation).to have_structure(vmhost1_config)
    end

    context 'includes DHCP options' do
      def check_dhcp_option(reference)
        option = @tool.kea_config['Dhcp4']['subnet4'].first['option-data'].find { |o|
                   o['name'] == reference['name']
                 }
        reference['space'] = 'dhcp4'
        reference['csv-format'] = true
        expect(option).to have_structure(reference)
      end

      it 'default gateway' do
      check_dhcp_option({'code' => 3,
                         'name' => 'routers',
                         'data' => '192.168.0.1'})
      end

      it 'DNS resolver' do
        check_dhcp_option({'code' => 6,
                            'name' => 'domain-name-servers',
                            'data' => '192.168.0.1'})
      end

      it 'TFTP server' do
        check_dhcp_option({'code' => 66,
                            'name' => 'tftp-server-name',
                            'data' => '192.168.0.1'})
      end

      it 'PXE boot file name' do
        check_dhcp_option({'code' => 67,
                            'name' => 'boot-file-name',
                            'data' => 'pxelinux.0'})
      end
    end
  end
end
