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
end
