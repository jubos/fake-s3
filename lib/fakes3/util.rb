module FakeS3
  module Util
    def Util.strip_before_and_after(string, strip_this)
      regex_friendly_strip_this = Regexp.escape(strip_this)
      string.gsub(/\A[#{regex_friendly_strip_this}]+|[#{regex_friendly_strip_this}]+\z/, '')
    end
  end
end
