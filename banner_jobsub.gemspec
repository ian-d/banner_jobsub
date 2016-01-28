# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'banner_jobsub/version'

Gem::Specification.new do |spec|
  spec.name          = "banner_jobsub"
  spec.version       = BannerJobsub::VERSION
  spec.authors       = ["Ian Dillon"]
  spec.email         = ["dillon@etsu.edu"]

  spec.summary       = %q{"Write Ellucian Banner Jobsub jobs in Ruby."}
  spec.homepage      = "http://github.com/ian-d/banner_jobsub"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_runtime_dependency "ruby-oci8", ">= 2.1.5"
  spec.add_runtime_dependency "formatr", ">= 1.10.1"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
