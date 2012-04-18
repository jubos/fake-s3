require 'bundler'
require 'rake/testtask'
include Rake::DSL
Bundler::GemHelper.install_tasks

namespace :test do
  Rake::TestTask.new(:runner) do |t|
    t.libs << "."
    t.test_files = FileList['test/*_test.rb']
  end
end

task :test do
  system("bundle exec foreman start")
end

task :default => :test
