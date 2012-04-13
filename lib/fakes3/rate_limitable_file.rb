module FakeS3
  class RateLimitableFile < File
    @@rate_limit = nil
    # Specify a rate limit in bytes per second
    def self.rate_limit
      @@rate_limit
    end

    def self.rate_limit=(rate_limit)
      @@rate_limit = rate_limit
    end

    def read(args)
      if @@rate_limit
        time_to_sleep = args / @@rate_limit
        sleep(time_to_sleep)
      end
      return super(args)
    end
  end
end
