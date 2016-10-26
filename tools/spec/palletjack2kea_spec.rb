require 'spec_helper'

load "palletjack2kea"

describe 'palletjack2kea' do
  it 'generates the correct JSON tree' do
    class PalletJack2Kea
      def argv
        ["-w", $EXAMPLE_WAREHOUSE,
          "-s", "dhcp-server-example-net"]
      end
    end

    tool = PalletJack2Kea.instance
    tool.process
    expect(tool.kea_config).to eql ({"Dhcp4"=>{"interfaces-config"=>{"interfaces"=>["*"]}, "lease-database"=>{"type"=>"memfile"}, "valid-lifetime"=>4000, "subnet4"=>[{"subnet"=>"192.168.0.0/24", "reservations"=>[{"hw-address"=>"14:18:77:ab:cd:ef", "ip-address"=>"192.168.0.1", "hostname"=>"vmhost1.example.com", "option-data"=>[{"code"=>15, "name"=>"domain-name", "space"=>"dhcp4", "csv-format"=>true, "data"=>"example.com"}]}, {"hw-address"=>"52:54:00:12:34:56", "ip-address"=>"192.168.0.2", "hostname"=>"testvm.example.com", "option-data"=>[{"code"=>15, "name"=>"domain-name", "space"=>"dhcp4", "csv-format"=>true, "data"=>"example.com"}]}], "option-data"=>[{"code"=>3, "name"=>"routers", "space"=>"dhcp4", "csv-format"=>true, "data"=>"192.168.0.1"}, {"code"=>6, "name"=>"domain-name-servers", "space"=>"dhcp4", "csv-format"=>true, "data"=>"192.168.0.1"}, {"code"=>66, "name"=>"tftp-server-name", "space"=>"dhcp4", "csv-format"=>true, "data"=>"192.168.0.1"}, {"code"=>67, "name"=>"boot-file-name", "space"=>"dhcp4", "csv-format"=>true, "data"=>"pxelinux.0"}], "next-server"=>"192.168.0.1"}]}})

  end
end
