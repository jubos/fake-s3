# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fakes3/version"

Gem::Specification.new do |s|
  s.name        = "fakes3"
  s.version     = FakeS3::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Curtis Spencer"]
  s.email       = ["thorin@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{FakeS3 is a server that simulates S3 commands so you can test your S3 functionality in your projects}
  s.description = %q{Use FakeS3 to test basic S3 functionality without actually connecting to S3}

  s.rubyforge_project = "fakes3"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "aws-s3"
  s.add_development_dependency "right_aws"
  #s.add_development_dependency "aws-sdk"
  #s.add_development_dependency "ruby-debug19"
  s.add_dependency "thor"
  s.add_dependency "builder"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
