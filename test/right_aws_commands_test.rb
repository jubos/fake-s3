require 'test/test_helper'
require 'fileutils'
#require 'fakes3/server'
require 'right_aws'
require 'time'

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

  def test_store_not_found
    begin
      obj = @s3.get("s3media","helloworldnotexist")
    rescue RightAws::AwsError
      assert $!.message.include?('NoSuchKey')
    rescue
      fail 'Should have caught NoSuchKey Exception'
    end
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

  # Test that GET requests with a delimiter return a list of
  def test_list_by_delimiter
    @s3.create_bucket("s3media")

    @s3.put("s3media", "delimited/item", "item")

    expected_prefixes = []
    (1..50).each do |i|
      key_prefix = "delimited/%02d/" % i
      @s3.put("s3media", key_prefix + "foo", "foo")
      @s3.put("s3media", key_prefix + "fie", "fie")
      expected_prefixes << key_prefix
    end

    key_names = []
    common_prefixes = []
    @s3.incrementally_list_bucket("s3media", {:prefix => "delimited", :delimiter => '/'}) do |currentResponse|
      common_prefixes += currentResponse[:common_prefixes]
    end
    assert_equal ["delimited/"], common_prefixes

    common_prefixes = []
    @s3.incrementally_list_bucket("s3media", {:prefix => "delimited/", :delimiter => '/', "max-keys" => 5}) do |currentResponse|
      key_names += currentResponse[:contents].map do |key|
        key[:key]
      end
      common_prefixes += currentResponse[:common_prefixes]
    end
    assert_equal expected_prefixes, common_prefixes
    assert_equal ["delimited/item"], key_names
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

  def test_copy_in_place
    @s3.put("s3media","foo","Hello World")
    @s3.copy("s3media","foo","s3media","foo")
    obj = @s3.get("s3media","foo")
    assert_equal "Hello World",obj[:object]
  end

  def test_copy_replace_metadata
    @s3.put("s3media","foo","Hello World",{"content-type"=>"application/octet-stream"})
    obj = @s3.get("s3media","foo")
    assert_equal "Hello World",obj[:object]
    assert_equal "application/octet-stream",obj[:headers]["content-type"]
    @s3.copy("s3media","foo","s3media","foo",:replace,{"content-type"=>"text/plain"})
    obj = @s3.get("s3media","foo")
    assert_equal "Hello World",obj[:object]
    assert_equal "text/plain",obj[:headers]["content-type"]
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

  def test_if_none_match
    @s3.put("s3media","if_none_match_test","Hello World 1!")
    obj = @s3.get("s3media","if_none_match_test")
    tag = obj[:headers]["etag"]
    begin
      @s3.get("s3media", "if_none_match_test", {"If-None-Match"=>tag})
    rescue URI::InvalidURIError
      # expected error for 304
    else
      fail 'Should have encountered an error due to the server not returning a response due to caching'
    end
    @s3.put("s3media","if_none_match_test","Hello World 2!")
    obj = @s3.get("s3media", "if_none_match_test", {"If-None-Match"=>tag})
    assert_equal "Hello World 2!",obj[:object]
  end

  def test_if_modified_since
    @s3.put("s3media","if_modified_since_test","Hello World 1!")
    obj = @s3.get("s3media","if_modified_since_test")
    modified = obj[:headers]["last-modified"]
    begin
      @s3.get("s3media", "if_modified_since_test", {"If-Modified-Since"=>modified})
    rescue URI::InvalidURIError
      # expected error for 304
    else
      fail 'Should have encountered an error due to the server not returning a response due to caching'
    end
    # Granularity of an HTTP Date is 1 second which isn't enough for the test
    # so manually rewind the clock by a second
    timeInThePast = Time.httpdate(modified) - 1
    begin
      obj = @s3.get("s3media", "if_modified_since_test", {"If-Modified-Since"=>timeInThePast.httpdate()})
    rescue
      fail 'Should have been downloaded since the date is in the past now'
    else
      #expected scenario
    end
  end

end
