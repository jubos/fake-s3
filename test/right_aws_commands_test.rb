require 'test/test_helper'
require 'fileutils'
#require 'fakes3/server'
require 'right_aws'

class RightAWSCommandsTest < Test::Unit::TestCase

  def setup
    @s3 = RightAws::S3Interface.new('1E3GDYEOGFJPIT7XXXXXX','hgTHt68JY07JKUY08ftHYtERkjgtfERn57XXXXXX',
                                    {:multi_thread => false, :server => 'localhost',
                                      :port => 10453, :protocol => 'http',:logger => Logger.new("/dev/null"),:no_subdomains => true })
  end

  def teardown
  end

  def test_create_bucket
    bucket = @s3.create_bucket("s3media")
    assert_not_nil bucket
  end

  def test_store
    @s3.put("s3media","helloworld","Hello World Man!")
    obj = @s3.get("s3media","helloworld")
    assert_equal "Hello World Man!",obj[:object]

    obj = @s3.get("s3media","helloworld")
  end

  def test_large_store
    @s3.put("s3media","helloworld","Hello World Man!")
    buffer = ""
    500000.times do
      buffer << "#{(rand * 100).to_i}"
    end

    buf_len = buffer.length
    @s3.put("s3media","big",buffer)

    output = ""
    @s3.get("s3media","big") do |chunk|
      output << chunk
    end
    assert_equal buf_len,output.size
  end

  def test_multi_directory
    @s3.put("s3media","dir/right/123.txt","recursive")
    output = ""
    obj = @s3.get("s3media","dir/right/123.txt") do |chunk|
      output << chunk
    end
    assert_equal "recursive", output
  end

  def test_intra_bucket_copy
    @s3.put("s3media","original.txt","Hello World")
    @s3.copy("s3media","original.txt","s3media","copy.txt")
    obj = @s3.get("s3media","copy.txt")
    assert_equal "Hello World",obj[:object]
  end

  def test_larger_lists
    @s3.create_bucket('right_aws_many')
    (0..50).each do |i|
      ('a'..'z').each do |letter|
        name = "#{letter}#{i}"
        @s3.put('right_aws_many', name, 'asdf')
      end
    end

    keys = @s3.list_bucket('right_aws_many')
    assert_equal(1000, keys.size)
    assert_equal('a0', keys.first[:key])
  end

  def test_destroy_bucket
    @s3.create_bucket('deletebucket')
    @s3.delete_bucket('deletebucket')

    begin
      bucket = @s3.list_bucket('deletebucket')
      fail("Shouldn't succeed here")
    rescue RightAws::AwsError
      assert $!.message.include?('NoSuchBucket')
    rescue
      fail 'Should have caught NoSuchBucket Exception'
    end

  end

end
