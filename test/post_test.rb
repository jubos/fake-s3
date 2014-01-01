require 'test/test_helper'
require 'rest-client'

class PostTest < Test::Unit::TestCase
  # Make sure you have a posttest.localhost in your /etc/hosts/
  def setup
    @url='http://posttest.localhost:10453/'
  end

  def teardown
  end

  def test_options
    res= RestClient.options(@url) { |response|
      assert_equal(response.headers[:access_control_allow_origin],"*")
    }
  end

  def test_redirect
    res = RestClient.post(
      @url,
      'key'=>'uploads/12345/${filename}',
      'success_action_redirect'=>'http://somewhere.else.com/',
      'file'=>File.new(__FILE__,"rb")
    ) { |response|
      assert_equal(response.code, 307)
      assert_equal(response.headers[:location], 'http://somewhere.else.com/')
    }
  end

  def test_status_200
    res = RestClient.post(
      @url,
      'key'=>'uploads/12345/${filename}',
      'success_action_status'=>'200',
      'file'=>File.new(__FILE__,"rb")
    ) { |response|
      assert_equal(response.code, 200)
    }
  end

  def test_status_201
    res = RestClient.post(
      @url,
      'key'=>'uploads/12345/${filename}',
      'success_action_status'=>'201',
      'file'=>File.new(__FILE__,"rb")
    ) { |response|
      assert_equal(response.code, 201)
      assert_match(%r{^\<\?xml.*uploads/12345/post_test\.rb}m, response.body)
    }
  end

end
