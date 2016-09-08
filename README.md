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

- warehouse/
  - transforms.yaml
  - building/
    - B101/
      - location.yaml
    - ...
  - chassis/
    - 1BC4F7H/
      - building -> ../../building/B101
    - ...
  - machine/
    - kvmhost1/
      - chassis -> ../../chassis/1BC4F7H
        - architecture.yaml
    - ...
  - virtual_machine/
    - kvmguest1/
      - system -> ../../system/kvmhost1
    - ...
  - system/
    - kvmhost1/
      - machine -> ../../machine/kvmhost1
      - roles.yaml
    - kvmguest1/
      - virtual_machine -> ../../virtual_machine/kvmguest1
      - roles.yaml

```bash
% irb -r palletjack
2.3.1 :001 > jack = PalletJack.new("warehouse")
2.3.1 :002 > jack["system"]
 => #<Set: {#<PalletJack::Pallet:f8f1ec>, #<PalletJack::Pallet:10775a0>}> 
2.3.1 :003 > jack["system"].each{|pallet| puts pallet["host.name"]}
kvmhost1
kvmguest1
 => #<Set: {#<PalletJack::Pallet:f8f1ec>, #<PalletJack::Pallet:10775a0>}> 
2.3.1 :004 > jack["system"].each{|pallet| puts pallet["chassis.serial"]}
1BC5F7H
1BC5F7H
 => #<Set: {#<PalletJack::Pallet:f8f1ec>, #<PalletJack::Pallet:10775a0>}> 
2.3.1 :005 > jack["system", with_all:{"pallet.references.system" => /^kvmhost1$/}].each{|pallet| puts pallet["host.name"]}
kvmguest1
 => #<Set: {#<PalletJack::Pallet:10775a0>}> 
```

## Creating warehouse objects

Warehouse objects are simple directories, so you can create them using
`mkdir`. To simplify the process, there are some tools that create
objects with standard links and YAML structures for you. Example:

```bash
$ create_domain -w /tmp/warehouse -d example.com -n 192.168.42.0/24
$ create_system -w /tmp/warehouse -s vmhost -d example.com -o CentOS-7.2.1511-x86_64
$ create_ipv4_interface -w /tmp/warehouse -s vmhost -d example.com -m 52:54:00:8d:be:fe -i 192.168.42.1 -n 192.168.42.0/24
$ dump_pallet -w /tmp/warehouse -t ipv4_interface
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
    resolver: ''
    ns:
    - ''
    domain: example.com
    name: vmhost
    fqdn: vmhost.example.com
  soa-ns: ''
  soa-contact: ''
  layer2:
    name: ''
    address: 52:54:00:8d:be:fe
system:
  os: CentOS-7.2.1511-x86_64
  role:
  - ''
  name: vmhost
host:
  pxelinux:
    config: CentOS-7.2.1511-x86_64
```
