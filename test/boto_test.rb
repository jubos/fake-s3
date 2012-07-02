require 'test/test_helper'
require 'fileutils'

class BotoTest < Test::Unit::TestCase
  def setup
    cmdpath = File.expand_path(File.join(File.dirname(__FILE__),'botocmd.py'))
    @botocmd = "python #{cmdpath} -t localhost -p 10453"
  end

  def teardown
  end

  def test_store
    File.open(__FILE__,'rb') do |input|
      File.open("/tmp/fakes3_upload",'wb') do |output|
        output << input.read
      end
    end
    output = `#{@botocmd} put /tmp/fakes3_upload s3://s3cmd_bucket/upload`
    assert_match(/stored/,output)

    FileUtils.rm("/tmp/fakes3_upload")
  end

end
