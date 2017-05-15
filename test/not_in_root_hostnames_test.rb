require 'test/test_helper'
require 'fileutils'
require 'right_aws'
require 'time'


class NotInRootHostnamesTest < Test::Unit::TestCase

  def setup
    @s3 = RightAws::S3Interface.new('1E3GDYEOGFJPIT7XXXXXX','hgTHt68JY07JKUY08ftHYtERkjgtfERn57XXXXXX',
                                    {:multi_thread => false, :server => 'notinroothostnames.localhost',
                                      :port => 10453, :protocol => 'http', :logger => Logger.new("/dev/null"),
                                      :no_subdomains => true })
  end

  def teardown
  end

  def test_intra_bucket_copy
    @s3.put("s3media", "original.txt", "Hello World")
    @s3.copy("s3media", "original.txt", "s3media", "copy.txt")
    obj = @s3.get("s3media", "copy.txt")
    assert_equal "Hello World", obj[:object]
  end

  def test_copy_in_place
    @s3.put("s3media", "copy-in-place", "Hello World")
    @s3.copy("s3media", "copy-in-place", "s3media", "copy-in-place")
    obj = @s3.get("s3media", "copy-in-place")
    assert_equal "Hello World", obj[:object]
  end

end
