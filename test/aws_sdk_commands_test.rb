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

  def test_metadata
    file_path = './test_root/test_metadata/metaobject'
    FileUtils.rm_rf file_path

    bucket = @s3.buckets["test_metadata"]
    object = bucket.objects["metaobject"]
    object.write(
      'data',
      # this is sent as header x-amz-storage-class
      :storage_class => 'REDUCED_REDUNDANCY',
      # this is sent as header x-amz-meta-custom1
      :metadata => {
        "custom1" => "foobar"
      }
    )
    assert object.exists?
    metadata_file = YAML.load(IO.read("#{file_path}/.fakes3_metadataFFF/metadata"))

    assert metadata_file.has_key?(:custom_metadata), 'Metadata file does not contain a :custom_metadata key'
    assert metadata_file[:custom_metadata].has_key?('custom1'), ':custom_metadata does not contain field "custom1"'
    assert_equal 'foobar', metadata_file[:custom_metadata]['custom1'], '"custom1" does not equal expected value "foobar"'

    assert metadata_file.has_key?(:amazon_metadata), 'Metadata file does not contain an :amazon_metadata key'
    assert metadata_file[:amazon_metadata].has_key?('storage-class'), ':amazon_metadata does not contain field "storage-class"'
    assert_equal 'REDUCED_REDUNDANCY', metadata_file[:amazon_metadata]['storage-class'], '"storage-class" does not equal expected value "REDUCED_REDUNDANCY"'

  end
end
