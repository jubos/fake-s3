$:.unshift File.expand_path("../lib", __FILE__)
require 'fakes3'

run FakeS3::App.new(FakeS3::FileStore.new(ENV['FAKE_S3_ROOT']), ENV['FAKE_S3_HOSTNAME'])