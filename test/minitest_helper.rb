# LICENSE:
#
# (The MIT License)
#
# Copyright © Ryan Davis, seattle.rb
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# The following is from minitest:
# TODO - decide whether to switch to minitest or what to do about these:

def capture_io
  require 'stringio'

  captured_stdout, captured_stderr = StringIO.new, StringIO.new

  orig_stdout, orig_stderr = $stdout, $stderr
  $stdout, $stderr         = captured_stdout, captured_stderr

  begin
    yield
  ensure
    $stdout = orig_stdout
    $stderr = orig_stderr
  end

  return captured_stdout.string, captured_stderr.string
end

def assert_output stdout = nil, stderr = nil
  out, err = capture_io do
    yield
  end

  err_msg = Regexp === stderr ? :assert_match : :assert_equal if stderr
  out_msg = Regexp === stdout ? :assert_match : :assert_equal if stdout

  y = send err_msg, stderr, err, "In stderr" if err_msg
  x = send out_msg, stdout, out, "In stdout" if out_msg

  (!stdout || x) && (!stderr || y)
end
