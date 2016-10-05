# Pallet Jack
Pallet Jack is a lightweight configuration management database, utilizing
the power of a Posix file system to store yaml serialized key-value trees.

A database is created from a warehouse (directory) of different kinds
(directory) of pallets (directory), each containing boxes (yaml files)
with keys. Pallets can also contain references to other pallets (symlinks)
to build a Directed Acyclic Graph of key-value search nodes.

The entire structure is indended to live beside configuration management
code and data in a version control system repository, to enable tagged
releases of both code, data and metadata.

The toplevel `transforms.yaml` file defines key-value transforms to perform
when loading the database, e.g. synthesize key-values from pallet metadata.

```
warehouse
├── building
│   └── 1
│       └── location.yaml
├── chassis
│   └── Example:FastServer-128:1234ABCD
│       ├── identity.yaml
│       ├── location.yaml
│       └── rack -> ../../rack/1-A-2/
├── domain
│   └── example.com
│       ├── dns.yaml
│       ├── ipv4_network -> ../../ipv4_network/192.168.0.0_24/
│       └── services.yaml
├── ipv4_interface
│   ├── 192.168.0.1
│   │   ├── dns.yaml
│   │   ├── domain -> ../../domain/example.com/
│   │   ├── ipv4_network -> ../../ipv4_network/192.168.0.0_24/
│   │   ├── phy_nic -> ../../phy_nic/14:18:77:ab:cd:ef/
│   │   └── system -> ../../system/vmhost1/
│   └── 192.168.0.2
│       ├── domain -> ../../domain/example.com/
│       ├── ipv4_network -> ../../ipv4_network/192.168.0.0_24/
│       ├── phy_nic -> ../../phy_nic/52:54:00:12:34:56/
│       └── system -> ../../system/testvm/
├── ipv4_network
│   └── 192.168.0.0_24
│       ├── dhcp.yaml
│       └── identity.yaml
├── machine
│   ├── testvm
│   │   ├── host -> ../../system/vmhost1/
│   │   └── type.yaml
│   └── vmhost1
│       ├── chassis -> ../../chassis/Example:FastServer-128:1234ABCD/
│       └── type.yaml
├── netinstall
│   ├── CentOS-7.2.1511-x86_64-Kickstart_sda
│   │   ├── kickstart.yaml
│   │   └── os -> ../../os/CentOS-7.2.1511-x86_64
│   ├── CentOS-7.2.1511-x86_64-Kickstart_vda
│   │   ├── kickstart.yaml
│   │   └── os -> ../../os/CentOS-7.2.1511-x86_64
│   └── CentOS-7.2.1511-x86_64-Manual
│       ├── kickstart.yaml
│       └── os -> ../../os/CentOS-7.2.1511-x86_64
├── os
│   └── CentOS-7.2.1511-x86_64
│       └── kickstart.yaml
├── phy_nic
│   ├── 14:18:77:ab:cd:ef
│   │   ├── chassis -> ../../chassis/Example:FastServer-128:1234ABCD/
│   │   └── location.yaml
│   └── 52:54:00:12:34:56
│       ├── identity.yaml
│       └── phy_nic -> ../../phy_nic/14:18:77:ab:cd:ef/
├── rack
│   └── 1-A-2
│       ├── location.yaml
│       └── room -> ../../room/server-room-1/
├── room
│   └── server-room-1
│       ├── building -> ../../building/1
│       ├── identity.yaml
│       └── location.yaml
├── service
│   ├── dhcp-server-example-net
│   │   └── kea.yaml
│   └── dns-resolver-example-com
│       └── unbound.yaml
├── system
│   ├── testvm
│   │   ├── architecture.yaml
│   │   ├── domain -> ../../domain/example.com/
│   │   ├── machine -> ../../machine/testvm/
│   │   ├── netinstall -> ../../netinstall/CentOS-7.2.1511-x86_64-Kickstart_vda/
│   │   └── role.yaml
│   └── vmhost1
│       ├── architecture.yaml
│       ├── domain -> ../../domain/example.com/
│       ├── machine -> ../../machine/vmhost1/
│       ├── netinstall -> ../../netinstall/CentOS-7.2.1511-x86_64-Kickstart_sda/
│       └── role.yaml
└── transforms.yaml
```

```bash
% irb -r palletjack
2.3.1 :001 > jack = PalletJack.new('warehouse')
2.3.1 :002 > testvm = jack.fetch('system', name:'testvm')
 => #<PalletJack::Pallet:148ac64>
2.3.1 :003 > testvm['host.type']
 => "virtual"
2.3.1 :004 > jack['system'].each {|pallet| puts "#{pallet['net.dns.name']}: #{pallet['chassis.serial']}" }
vmhost1: 1234ABCD
testvm: 1234ABCD
 => #<Set: {#<PalletJack::Pallet:16abed0>, #<PalletJack::Pallet:148ac64>}>
2.3.1 :005 > jack['system', with_all:{'host.type' => 'virtual'}].each {|system| puts system['net.dns.name'] }
testvm
 => #<Set: {#<PalletJack::Pallet:148ac64>}>
```

## Creating warehouse objects

Warehouse objects are simple directories, so you can create them using
`mkdir`. To simplify the process, there are some tools that create
objects with standard links and YAML structures for you. Example:

```bash
$ create_domain --warehouse /tmp/warehouse --domain example.com --network 192.168.42.0/24
$ create_system --warehouse /tmp/warehouse --system vmhost --domain example.com --os CentOS-7.2.1511-x86_64
$ create_ipv4_interface --warehouse /tmp/warehouse --system vmhost --domain example.com --mac 52:54:00:8d:be:fe --ipv4 192.168.42.1 --network 192.168.42.0/24
$ dump_pallet --warehouse /tmp/warehouse --type ipv4_interface 192.168.42.1
```

```yaml
---
pallet:
  ipv4_network: 192.168.42.0_24
  boxes: []
  references:
    ipv4_network: 192.168.42.0_24
    domain: example.com
    phy_nic: 52:54:00:8d:be:fe
    os: CentOS-7.2.1511-x86_64
    system: vmhost
  domain: example.com
  phy_nic: 52:54:00:8d:be:fe
  os: CentOS-7.2.1511-x86_64
  system: vmhost
  ipv4_interface: 192.168.42.1
net:
  dhcp:
    tftp-server: ''
    boot-file: ''
  ipv4:
    gateway: ''
    prefixlen: '24'
    cidr: 192.168.42.0/24
    address: 192.168.42.1
  dns:
    resolver:
    - ''
    ns:
    - ''
    soa-ns: ''
    soa-contact: ''
    domain: example.com
    name: vmhost
    fqdn: vmhost.example.com
  service:
    syslog:
    - address: syslog-archive.example.com
      port: 514
      protocol: udp
    - address: logstash.example.com
      port: 5514
      protocol: tcp
  layer2:
    name: ''
    address: 52:54:00:8d:be:fe
host:
  kickstart:
    baseurl: http://mirror.centos.org/centos/7.2.1511/os/x86_64/
  pxelinux:
    kernel: "/boot/CentOS-7.2.1511-x86_64/vmlinuz"
    config: CentOS-7.2.1511-x86_64
system:
  os: CentOS-7.2.1511-x86_64
  role:
  - ''
  name: vmhost
```
