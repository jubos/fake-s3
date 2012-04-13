require 'test/test_helper'
require 'fileutils'
require 'fakes3/server'
require 'aws/s3'

class S3CommandsTest < Test::Unit::TestCase
  include AWS::S3

  def setup
    AWS::S3::Base.establish_connection!(:access_key_id => "123", :secret_access_key => "abc", :server => "localhost", :port => "10453" )
  end

  def teardown
    AWS::S3::Base.disconnect!
  end

  def test_create_bucket
    bucket = Bucket.create("mybucket")
    assert_not_nil bucket
  end

  def test_store
    bucket = Bucket.create("mybucket")
    S3Object.store("hello","world","mybucket")

    output = ""
    obj = S3Object.stream("hello","mybucket") do |chunk|
      output << chunk
    end
    assert_equal "world", output
  end

  def test_large_store
    bucket = Bucket.create("mybucket")
    buffer = ""
    500000.times do
      buffer << "#{(rand * 100).to_i}"
    end

    buf_len = buffer.length
    S3Object.store("big",buffer,"mybucket")

    output = ""
    S3Object.stream("big","mybucket") do |chunk|
      output << chunk
    end
    assert_equal buf_len,output.size
  end

  def test_multi_directory
    bucket = Bucket.create("mybucket")
    S3Object.store("dir/myfile/123.txt","recursive","mybucket")

    output = ""
    obj = S3Object.stream("dir/myfile/123.txt","mybucket") do |chunk|
      output << chunk
    end
    assert_equal "recursive", output
  end

  def test_find_nil_bucket
    begin
      bucket = Bucket.find("unknown")
      assert_fail "Bucket.find didn't throw an exception"
    rescue
      assert_equal AWS::S3::NoSuchBucket,$!.class
    end
  end
end
