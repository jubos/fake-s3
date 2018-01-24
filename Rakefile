require 'rubygems'
require 'bundler'
require 'rake/testtask'
include Rake::DSL
Bundler::GemHelper.install_tasks

Rake::TestTask.new(:test) do |t|
  t.libs << "."
  t.test_files =
    FileList['test/*_test.rb'].exclude('test/s3_commands_test.rb')

  # A lot of the gems like right aws and amazon sdk have a bunch of warnings, so
  # this suppresses them for the test runs
  t.warning = false
end

desc "Run the test_server"
task :test_server do |t|
  system("bundle exec bin/fakes3 --port 10453 --root test_root  --corspostputallowheaders 'Authorization, Content-Length, Cache-Control'")
end

task :default => :test
