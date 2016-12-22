# -*- encoding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'lib', 'fakes3', 'version')

Gem::Specification.new do |s|
  s.name        = "fakes3"
  s.version     = FakeS3::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Curtis Spencer"]
  s.email       = ["thorin@gmail.com"]
  s.homepage    = "https://github.com/jubos/fake-s3"
  s.summary     = %q{Fake S3 is a server that simulates S3 commands so you can test your S3 functionality in your projects}
  s.description = %q{Use Fake S3 to test basic S3 functionality without actually connecting to S3}
  s.license     = "MIT"

  s.rubyforge_project = "fakes3"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "aws-s3"
  s.add_development_dependency "right_aws"
  s.add_development_dependency "rest-client"
  s.add_development_dependency "rake"
  s.add_development_dependency "aws-sdk", "~> 2"
  s.add_development_dependency "aws-sdk-v1"
  s.add_development_dependency "test-unit"
  s.add_development_dependency "mocha"
  #s.add_development_dependency "ruby-debug"
  #s.add_development_dependency "debugger"
  s.add_dependency "thor"
  s.add_dependency "builder"

  s.files         = Dir['lib/**/*']
  s.test_files    = Dir['test/**/*']
  s.executables   = "fakes3"
  s.require_paths = ["lib"]
end
