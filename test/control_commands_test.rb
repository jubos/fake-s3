require 'test/test_helper'
require 'aws/s3'

class ControlCommandsTest < Test::Unit::TestCase
  include AWS::S3

  def setup
    @test_root = File.expand_path '../../test_root', __FILE__
    clear_test_root
    @file_store = FakeS3::FileStore.new @test_root
    AWS::S3::Base.establish_connection!(:access_key_id => "123",
                                        :secret_access_key => "abc",
                                        :server => "localhost",
                                        :port => "10453" )
  end

  def teardown
    AWS::S3::Base.disconnect!
    #clear_test_root
  end

  def test_list_all
    key_count = 0
    %w(bucket_one bucket_two).each do |bucket_name|
      Bucket.create bucket_name
      2.times do
        S3Object.store "some/key/#{key_count+=1}", 'some data', bucket_name
      end
    end
    expected =
        "BUCKET\tOBJECT_NAME\tSTORAGE_CLASS\n" +
        "bucket_one\tsome/key/1\tSTANDARD\n" +
        "bucket_one\tsome/key/2\tSTANDARD\n" +
        "bucket_two\tsome/key/3\tSTANDARD\n" +
        "bucket_two\tsome/key/4\tSTANDARD"
    assert_equal expected, FakeS3::FileStore.new(@test_root).list_all
  end

  def clear_test_root
    FileUtils.rm_rf @test_root
  end
end