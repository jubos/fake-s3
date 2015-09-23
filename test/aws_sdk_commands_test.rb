require 'test/test_helper'
require 'aws-sdk-v1'

class AwsSdkCommandsTest < Test::Unit::TestCase
  def setup
    @s3 = AWS::S3.new(:access_key_id => '123',
                      :secret_access_key => 'abc',
                      :s3_endpoint => 'localhost',
                      :s3_port => 10453,
                      :use_ssl => false)
  end

  def test_copy_to
    bucket = @s3.buckets["test_copy_to"]
    object = bucket.objects["key1"]
    object.write("asdf")

    assert object.exists?
    object.copy_to("key2")

    assert_equal 2, bucket.objects.count
  end

  def test_multipart_upload
    bucket = @s3.buckets["test_multipart_upload"]
    object = bucket.objects["key1"]
    object.write("thisisaverybigfile", :multipart_threshold => 5)
    assert object.exists?
    assert_equal "thisisaverybigfile", object.read
  end

  def test_delete_multiple
    #assemble
    bucket = @s3.buckets["test_delete_multiple"]
    object = bucket.objects["key1"]
    object.write("asdf")
    object.copy_to("key2")
    assert_equal 2, bucket.objects.count

    #act
    bucket.objects.delete_all

    #assert
    assert_equal 0, bucket.objects.count
  end

  def test_delete_multiple_with_prefix
    #assemble
    bucket = @s3.buckets["test_delete_multiple"]
    object = bucket.objects["key1"]
    object.write("asdf")
    object.copy_to("prefix1/key2")
    object.copy_to("prefix1/key3")
    assert_equal 3, bucket.objects.count

    #act
    bucket.objects.with_prefix('prefix1/').delete_all

    #assert
    assert_equal 1, bucket.objects.count
  end
end
