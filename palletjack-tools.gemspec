#-*- ruby -*-
Gem::Specification.new do |s|
  s.name	= 'palletjack-tools'
  s.summary	= 'Tools for the Pallet Jack Lightweight Configuration Management Database'
  s.description	= File.read(File.join(File.dirname(__FILE__), 'README.md'))
  s.homepage    = 'https://github.com/saab-simc-admin/palletjack'
  s.version	= '0.0.3'
  s.author	= 'Karl-Johan Karlsson'
  s.email	= 'karl-johan.karlsson@saabgroup.com'
  s.license	= 'MIT'

  s.platform	= Gem::Platform::RUBY
  s.required_ruby_version = '~>2'
  s.add_runtime_dependency 'palletjack', s.version
  s.add_runtime_dependency 'kvdag', '~> 0.0.3'
  s.add_runtime_dependency 'dns-zone', '~> 0.3'
  s.add_runtime_dependency 'ruby-ip', '~> 0.9'
  s.add_runtime_dependency 'rugged', '~> 0.24'
  s.files	= [ 'README.md', 'LICENSE' ]
  s.files	+= Dir['tools/*']
  s.files	+= [ 'lib/palletjack/tool-support.rb' ]
  s.bindir      = 'tools/'
  s.executables = ['dump_pallet', 'palletjack2kea', 'palletjack2salt',
    'palletjack2pxelinux', 'create_domain', 'create_system',
    'create_ipv4_interface', 'palletjack2knot', 'palletjack2unbound']
  s.has_rdoc	= true
end
