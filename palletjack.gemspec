#-*- ruby -*-
Gem::Specification.new do |s|
  s.name	= 'palletjack'
  s.summary	= 'Lightweight Configuration Management Database'
  s.description	= File.read(File.join(File.dirname(__FILE__), 'README.md'))
  s.homepage    = 'https://github.com/saab-simc-admin/palletjack'
  s.version	= '0.0.2'
  s.author	= 'Calle Englund'
  s.email	= 'calle.englund@saabgroup.com'
  s.license	= 'MIT'

  s.platform	= Gem::Platform::RUBY
  s.required_ruby_version = '~>2'
  s.add_runtime_dependency 'activesupport', '~>5'
  s.add_runtime_dependency 'kvdag', '~>0'
  s.files	= [ 'README.md', 'LICENSE' ]
  s.files	+= Dir['lib/**/*.rb']
  s.files	+= Dir['bin/*']
  s.executables	= ['dump_pallet']
  s.test_files	= Dir['test/test*.rb']
  s.has_rdoc	= true
end
