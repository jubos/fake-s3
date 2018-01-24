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
    RestClient.options(@url) do |response|
      assert_equal(response.code, 200)
      assert_equal(response.headers[:access_control_allow_origin],"*")
      assert_equal(response.headers[:access_control_allow_methods], "PUT, POST, HEAD, GET, OPTIONS")
      assert_equal(response.headers[:access_control_allow_headers], "Accept, Content-Type, Authorization, Content-Length, ETag, X-CSRF-Token, Content-Disposition")
      assert_equal(response.headers[:access_control_expose_headers], "ETag")
    end
  end

  def test_redirect
    res = RestClient.post(
      @url,
      'key'=>'uploads/12345/${filename}',
      'success_action_redirect'=>'http://somewhere.else.com/?foo=bar',
      'file'=>File.new(__FILE__,"rb")
    ) { |response|
      assert_equal(response.code, 303)
      assert_equal(response.headers[:location], 'http://somewhere.else.com/?foo=bar&bucket=posttest&key=uploads%2F12345%2Fpost_test.rb')
      # Tests that CORS Headers can be set from command line
      assert_equal(response.headers[:access_control_allow_headers], 'Authorization, Content-Length, Cache-Control')
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
      # Tests that CORS Headers can be set from command line
      assert_equal(response.headers[:access_control_allow_headers], 'Authorization, Content-Length, Cache-Control')
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
      # Tests that CORS Headers can be set from command line
      assert_equal(response.headers[:access_control_allow_headers], 'Authorization, Content-Length, Cache-Control')
    }
  end

end
