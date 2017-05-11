#!/usr/bin/env ruby

# Write DNS server zone files from a Palletjack warehouse
#
# Data model assumptions:
# - Each domain corresponds uniquely to one IPv4 network
#
# The YAML key "net.dns.alias" is used to create CNAME aliases for
# each interface. This means that if a "system" object specifies
# "net.dns.alias", each of its interfaces will get that alias in its
# own domain. Aliases explicitly specified on a single interface will
# override this.
#
# To adapt this code to a specific DNS server, implement #zone_config
# to take the name of a zone and output the configuration block for
# telling the server about it. Also, implement #toolname to return the
# name of the running tool.

require 'palletjack/tool'
require 'dns/zone'
require 'ip'

class PalletJack2Zones < PalletJack::Tool
  def toolname
    'PalletJack2Zones base class'
  end

  def zone_config(zone)
  end

  def parse_options(opts)
    opts.banner =
"Usage: #{$PROGRAM_NAME} -w <warehouse> -o <output directory>

Write DNS server zone files from a Palletjack warehouse"

    opts.on('-o DIR', '--output DIR', 'output directory', String) {|dir|
      options[:output] = dir
      options[:zone_dir] = config_path(:output, 'zones')
    }

    required_option :output
  end

  # Generate and store forward zone data for a Pallet Jack domain
  # object.

  def process_forward_zone(domain)
    absolute_domain_name = "#{domain['net.dns.domain']}."

    zone = DNS::Zone.new

    zone.origin = absolute_domain_name
    zone.ttl = domain['net.dns.ttl']

    zone.soa.serial = @serial
    zone.soa.label = zone.origin
    zone.soa.nameserver = domain['net.dns.soa-ns']
    zone.soa.email = "#{domain['net.dns.soa-contact']}.".sub('@', '.')

    if domain['net.dns.mx']
      domain['net.dns.mx'].each do |server|
        mx = DNS::Zone::RR::MX.new
        mx.label = absolute_domain_name
        mx.priority = server['priority']
        mx.exchange = server['server']
        zone.records << mx
      end
    end

    domain['net.dns.ns'].each do |address|
      ns = DNS::Zone::RR::NS.new
      ns.label = absolute_domain_name
      ns.nameserver = address
      zone.records << ns
    end

    if domain['net.dns.cname']
      domain['net.dns.cname'].each do |name, target|
        cname = DNS::Zone::RR::CNAME.new
        cname.label = name
        cname.domainname = target
        zone.records << cname
      end
    end

    if domain['net.dns.srv']
      domain['net.dns.srv'].each do |service|
        srv = DNS::Zone::RR::SRV.new
        srv.label = "_#{service['service']}._#{service['protocol']}"
        srv.target = service['target']
        srv.port = service['port']
        service['priority'] ||= 0
        srv.priority = service['priority']
        service['weight'] ||= 0
        srv.weight = service['weight']
        zone.records << srv
      end
    end

    domain.children(kind: 'ipv4_interface') do |interface|
      a = DNS::Zone::RR::A.new
      a.label = interface['net.dns.name']
      a.address = interface['net.ipv4.address']
      zone.records << a

      if interface['net.dns.alias']
        interface['net.dns.alias'].each do |label|
          cname = DNS::Zone::RR::CNAME.new
          cname.label = label
          cname.domainname = interface['net.dns.name']
          zone.records << cname
        end
      end
    end

    @forward_zones[domain['net.dns.domain']] = zone
  end

  # Generate and store reverse zone data for the IPv4 network
  # associated with a Pallet Jack domain object.

  def process_reverse_zone(domain)
    # Assume all delegations happen on octet boundaries for now.
    # TODO: RFC 2317 classless in-addr.arpa delegation

    reverse_zone = DNS::Zone.new

    absolute_reverse_zone_name = IP.new(domain['net.ipv4.cidr']).to_arpa

    prefix_octets, _ = domain['net.ipv4.prefixlen'].to_i.divmod(8)
    zone_file_name = absolute_reverse_zone_name.split('.')[-(2 + prefix_octets)..5].join('.')
    reverse_zone.origin = zone_file_name + '.'

    reverse_zone.ttl = domain['net.dns.ttl']

    reverse_zone.soa.serial = @serial
    reverse_zone.soa.label = reverse_zone.origin
    reverse_zone.soa.nameserver = domain['net.dns.soa-ns']
    reverse_zone.soa.email = "#{domain['net.dns.soa-contact']}.".sub('@', '.')

    domain['net.dns.ns'].each do |address|
      ns = DNS::Zone::RR::NS.new
      ns.label = reverse_zone.origin
      ns.nameserver = address
      reverse_zone.records << ns
    end

    domain.children(kind: 'ipv4_interface') do |interface|
      ptr = DNS::Zone::RR::PTR.new
      ptr.label = IP.new(interface['net.ipv4.address']).to_arpa
      ptr.name = "#{interface['net.dns.fqdn']}."
      reverse_zone.records << ptr
    end

    @reverse_zones[zone_file_name] = reverse_zone
  end

  def process
    config_dir :zone_dir

    # Temporary storage in hashes of "domain name" => DNS::Zone object
    @forward_zones = {}
    @reverse_zones = {}

    # Use Unix timestamp as serial number, and get it once so all zones get
    # the same one
    @serial = Time.now.utc.to_i

    jack.each(kind: 'domain') do |domain|
      process_forward_zone(domain)
      process_reverse_zone(domain)
    end
  end

  def output
    config_file :output, 'zones.conf' do |conf_file|
      conf_file << git_header(toolname)

      @forward_zones.each do |domain, zone|
        config_file :zone_dir, "#{domain}.zone" do |zonefile|
          zonefile << git_header(toolname, comment_char: ';')
          zonefile << zone.dump_pretty
          conf_file << zone_config(domain)
        end
      end

      @reverse_zones.each do |domain, zone|
        config_file :zone_dir, "#{domain}.zone" do |zonefile|
          zonefile << git_header(toolname, comment_char: ';')
          zonefile << zone.dump_pretty
          conf_file << zone_config(domain)
        end
      end
    end
  end
end
