require 'test/test_helper'
require 'fileutils'

class Boto3Test < Test::Unit::TestCase
  def setup
    cmdpath = File.expand_path(File.join(File.dirname(__FILE__),'boto3cmd.py'))
    @boto3cmd = "python #{cmdpath} -t localhost -p 10453"
  end

  def teardown
  end

  def test_store
    File.open(__FILE__,'rb') do |input|
      File.open("/tmp/fakes3_upload",'wb') do |output|
        output << input.read
      end
    end
    output = `#{@boto3cmd} put /tmp/fakes3_upload s3://s3cmd_bucket/upload`
    assert_match(/stored/,output)

    FileUtils.rm("/tmp/fakes3_upload")
  end

end
