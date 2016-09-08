require 'rubygems'
require 'bundler'
require 'rake/testtask'
include Rake::DSL
Bundler::GemHelper.install_tasks

Rake::TestTask.new(:test) do |t|
  t.libs << "."
  t.test_files =
    FileList['test/*_test.rb'].exclude('test/s3_commands_test.rb')
end

desc "Run the test_server"
task :test_server do |t|
  system("bundle exec bin/fakes3 --port 10453 --root test_root")
end

task :default => :test
