require 'test/test_helper'
require 'aws-sdk'

class AwsSdkV2CommandsTest < Test::Unit::TestCase
  def setup
    @creds = Aws::Credentials.new('123', 'abc')
    @s3    = Aws::S3::Client.new(credentials: @creds, region: 'us-east-1', endpoint: 'http://localhost:10453/')
    @resource = Aws::S3::Resource.new(client: @s3)
    @bucket = @resource.create_bucket(bucket: 'v2_bucket')

    # Delete all objects to avoid sharing state between tests
    @bucket.objects.each(&:delete)
  end

  def test_create_bucket
    bucket = @resource.create_bucket(bucket: 'v2_create_bucket')
    assert_not_nil bucket

    bucket_names = @resource.buckets.map(&:name)
    assert_not_nil bucket_names.index("v2_create_bucket")
  end

  def test_destroy_bucket
    @bucket.delete

    begin
      @s3.head_bucket(bucket: 'v2_bucket')
      assert_fail("Shouldn't succeed here")
    rescue
    end
  end

  def test_create_object
    object = @bucket.object('key')
    object.put(body: 'test')

    assert_equal 'test', object.get.body.string
  end

  def test_bucket_with_dots
    bucket = @resource.create_bucket(bucket: 'v2.bucket')
    object = bucket.object('key')
    object.put(body: 'test')

    assert_equal 'test', object.get.body.string
  end

  def test_delete_object
    object = @bucket.object('exists')
    object.put(body: 'test')

    assert_equal 'test', object.get.body.string

    object.delete

    assert_raise Aws::S3::Errors::NoSuchKey do
      object.get
    end
  end

  # TODO - get this test working
  #
  #def test_copy_object
  #  object = @bucket.object("key_one")
  #  object.put(body: 'asdf')

  #  # TODO: explore why 'key1' won't work but 'key_one' will
  #  object2 = @bucket.object('key_two')
  #  object2.copy_from(copy_source: 'testing_copy/key_one')

  #  assert_equal 2, @bucket.objects.count
  #end
end
