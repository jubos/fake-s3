require 'rubygems'
require 'bundler'
require 'rake/testtask'
include Rake::DSL
Bundler::GemHelper.install_tasks

Rake::TestTask.new(:test) do |t|
  t.libs << "."
  t.test_files =
    FileList['test/*_test.rb'].exclude('test/s3_commands_test.rb')
  test_server = spawn('bundle exec bin/fakes3 --port 10453 --root test_root', :err => '/dev/null')
  Signal.trap('EXIT') { Process.kill('SIGINT', test_server) }
end

task :default => :test
