# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bs_parser/version'

Gem::Specification.new do |gem|
  gem.name          = "bs_parser"
  gem.version       = BsParser::VERSION
  gem.authors       = ["Matt Early"]
  gem.email         = ["matt.early@gmail.com"]
  gem.description   = %q{Library to parse PDF and find transactions}
  gem.summary       = %q{Library to parse pdf and find transactions}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = "bs_parse"
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
