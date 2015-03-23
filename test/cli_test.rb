require 'test/test_helper'
require 'fakes3/cli'

class CLITest < Test::Unit::TestCase
  def setup
    super
    FakeS3::Server.any_instance.stubs(:serve)
  end

  def test_quiet_mode
    script = FakeS3::CLI.new([], :root => '.', :port => 4567, :quiet => true)
    assert_output('') do
      script.invoke(:server)
    end
  end
end
