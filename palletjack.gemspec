#-*- ruby -*-
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'palletjack/version'

Gem::Specification.new do |spec|
  spec.name     = 'palletjack'
  spec.version  = PalletJack::VERSION
  spec.authors  = ["Calle Englund"]
  spec.email    = ["calle.englund@saabgroup.com"]
  spec.summary	= 'Lightweight Configuration Management Database'
  spec.description = spec.summary
  spec.homepage    = 'https://github.com/saab-simc-admin/palletjack'
  spec.license	= 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|examples|tools)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.platform	= Gem::Platform::RUBY
  spec.required_ruby_version = '~>2'

  spec.add_runtime_dependency 'activesupport', '~>4'
  spec.add_runtime_dependency 'rugged', '~> 0.24'
  spec.add_runtime_dependency 'kvdag', '~> 0.1.3'

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec_structure_matcher", "~> 0.0.6"

  spec.has_rdoc	= true
end
