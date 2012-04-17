require 'test/test_helper'
require 'fileutils'

# You need to have s3cmd installed to use this
# Also, s3cmd doesn't support path style requests, so in order to properly test
# it you need to modify your dns by changing /etc/hosts or using dnsmasq
class S3CmdTest < Test::Unit::TestCase

  def setup
    config = File.expand_path(File.join(File.dirname(__FILE__),'local_s3_cfg'))
    @s3cmd = "s3cmd --config #{config}"
  end

  def teardown
  end

  def test_create_bucket
    `#{@s3cmd} mb s3://s3cmd_bucket`
    output = `#{@s3cmd} ls`
    assert_match(/s3cmd_bucket/,output)
  end

  def test_store
    File.open(__FILE__,'rb') do |input|
      File.open("/tmp/fakes3_upload",'wb') do |output|
        output << input.read
      end
    end
    output = `#{@s3cmd} put /tmp/fakes3_upload s3://s3cmd_bucket/upload`
    assert_match(/stored/,output)

    FileUtils.rm("/tmp/fakes3_upload")
  end

  def test_acl
    File.open(__FILE__,'rb') do |input|
      File.open("/tmp/fakes3_acl_upload",'wb') do |output|
        output << input.read
      end
    end
    output = `#{@s3cmd} put /tmp/fakes3_acl_upload s3://s3cmd_bucket/acl_upload`
    assert_match(/stored/,output)

    output = `#{@s3cmd} --force setacl -P s3://s3cmd_bucket/acl_upload`
  end

  def test_large_store
  end

  def test_multi_directory
  end

  def test_intra_bucket_copy
  end

end
