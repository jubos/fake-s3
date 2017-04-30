require 'test/test_helper'
require 'fileutils'
#require 'fakes3/server'
require 'aws/s3'

class S3CommandsTest < Test::Unit::TestCase
  include AWS::S3

  def setup
    AWS::S3::Base.establish_connection!(:access_key_id => "123",
                                        :secret_access_key => "abc",
                                        :server => "localhost",
                                        :port => "10453" )
  end

  def teardown
    AWS::S3::Base.disconnect!
  end

  def test_create_bucket
    bucket = Bucket.create("ruby_aws_s3")
    assert_not_nil bucket

    bucket_names = []
    Service.buckets.each do |bucket|
      bucket_names << bucket.name
    end
    assert(bucket_names.index("ruby_aws_s3") >= 0)
  end

  def test_destroy_bucket
    Bucket.create("deletebucket")
    Bucket.delete("deletebucket")

    begin
      bucket = Bucket.find("deletebucket")
      assert_fail("Shouldn't succeed here")
    rescue
    end
  end

  def test_store
    bucket = Bucket.create("ruby_aws_s3")
    S3Object.store("hello", "world", "ruby_aws_s3")

    output = ""
    obj = S3Object.stream("hello", "ruby_aws_s3") do |chunk|
      output << chunk
    end
    assert_equal "world", output
  end

  def test_large_store
    bucket = Bucket.create("ruby_aws_s3")
    buffer = ""
    500000.times do
      buffer << "#{(rand * 100).to_i}"
    end

    buf_len = buffer.length
    S3Object.store("big",buffer,"ruby_aws_s3")

    output = ""
    S3Object.stream("big","ruby_aws_s3") do |chunk|
      output << chunk
    end
    assert_equal buf_len,output.size
  end

  def test_metadata_store
    assert_equal true, Bucket.create("ruby_aws_s3")
    bucket = Bucket.find("ruby_aws_s3")

    # Note well: we can't seem to access obj.metadata until we've stored
    # the object and found it again. Thus the store, find, store
    # runaround below.
    obj = bucket.new_object(:value => "foo")
    obj.key = "key_with_metadata"
    obj.store
    obj = S3Object.find("key_with_metadata", "ruby_aws_s3")
    obj.metadata[:param1] = "one"
    obj.metadata[:param2] = "two, three"
    obj.store
    obj = S3Object.find("key_with_metadata", "ruby_aws_s3")

    assert_equal "one", obj.metadata[:param1]
    assert_equal "two, three", obj.metadata[:param2]
  end

  def test_metadata_copy
    assert_equal true, Bucket.create("ruby_aws_s3")
    bucket = Bucket.find("ruby_aws_s3")

    # Note well: we can't seem to access obj.metadata until we've stored
    # the object and found it again. Thus the store, find, store
    # runaround below.
    obj = bucket.new_object(:value => "foo")
    obj.key = "key_with_metadata"
    obj.store
    obj = S3Object.find("key_with_metadata", "ruby_aws_s3")
    obj.metadata[:param1] = "one"
    obj.metadata[:param2] = "two, three"
    obj.store

    S3Object.copy("key_with_metadata", "key_with_metadata2", "ruby_aws_s3")
    obj = S3Object.find("key_with_metadata2", "ruby_aws_s3")

    assert_equal "one", obj.metadata[:param1]
    assert_equal "two, three", obj.metadata[:param2]
  end

  def test_multi_directory
    bucket = Bucket.create("ruby_aws_s3")
    S3Object.store("dir/myfile/123.txt","recursive","ruby_aws_s3")

    output = ""
    obj = S3Object.stream("dir/myfile/123.txt","ruby_aws_s3") do |chunk|
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

  def test_find_object
    bucket = Bucket.create('find_bucket')
    obj_name = 'short'
    S3Object.store(obj_name,'short_text','find_bucket')
    short = S3Object.find(obj_name,"find_bucket")
    assert_not_nil(short)
    assert_equal(short.value,'short_text')
  end

  def test_find_non_existent_object
    bucket = Bucket.create('find_bucket')
    obj_name = 'doesnotexist'
    assert_raise AWS::S3::NoSuchKey do
      should_throw = S3Object.find(obj_name,"find_bucket")
    end

    # Try something higher in the alphabet
    assert_raise AWS::S3::NoSuchKey do
      should_throw = S3Object.find("zzz","find_bucket")
    end
  end

  def test_exists?
    bucket = Bucket.create('ruby_aws_s3')
    obj_name = 'dir/myfile/exists.txt'
    S3Object.store(obj_name,'exists','ruby_aws_s3')
    assert S3Object.exists?(obj_name, 'ruby_aws_s3')
    assert !S3Object.exists?('dir/myfile/doesnotexist.txt','ruby_aws_s3')
  end

  def test_delete
    bucket = Bucket.create("ruby_aws_s3")
    S3Object.store("something_to_delete","asdf","ruby_aws_s3")
    something = S3Object.find("something_to_delete","ruby_aws_s3")
    S3Object.delete("something_to_delete","ruby_aws_s3")

    assert_raise AWS::S3::NoSuchKey do
      should_throw = S3Object.find("something_to_delete","ruby_aws_s3")
    end
  end

  def test_rename
    bucket = Bucket.create("ruby_aws_s3")
    S3Object.store("something_to_rename","asdf","ruby_aws_s3")
    S3Object.rename("something_to_rename","renamed","ruby_aws_s3")

    renamed = S3Object.find("renamed","ruby_aws_s3")
    assert_not_nil(renamed)
    assert_equal(renamed.value,'asdf')

    assert_raise AWS::S3::NoSuchKey do
      should_throw = S3Object.find("something_to_rename","ruby_aws_s3")
    end
  end

  def test_larger_lists
    Bucket.create("ruby_aws_s3_many")
    (0..50).each do |i|
      ('a'..'z').each do |letter|
        name = "#{letter}#{i}"
        S3Object.store(name,"asdf","ruby_aws_s3_many")
      end
    end

    bucket = Bucket.find("ruby_aws_s3_many")
    assert_equal(bucket.size,1000)
    assert_equal(bucket.objects.first.key,"a0")
  end


  # Copying an object
  #S3Object.copy 'headshot.jpg', 'headshot2.jpg', 'photos'

  # Renaming an object
  #S3Object.rename 'headshot.jpg', 'portrait.jpg', 'photos'

end
