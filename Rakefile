require 'rubygems'
require 'bundler'
require 'rake/testtask'
include Rake::DSL
Bundler::GemHelper.install_tasks

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/*_test.rb']
  t.ruby_opts = ['-rubygems'] if defined? Gem
  t.ruby_opts << '-I.'
end

desc "Run the test_server"
task :test_server do |t|
  system("bundle exec bin/fakes3 --port 10453 --root test_root")
end
