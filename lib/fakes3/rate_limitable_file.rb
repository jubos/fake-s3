module FakeS3
  class RateLimitableFile

    attr_reader :path, :pos
    def initialize(path, pos = nil)
      @path = path
      @pos = pos
    end

    @@rate_limit = nil
    # Specify a rate limit in bytes per second
    def self.rate_limit
      @@rate_limit
    end

    def self.rate_limit=(rate_limit)
      @@rate_limit = rate_limit
    end

    def read(args = nil)
      if @@rate_limit
        time_to_sleep = args / @@rate_limit
        sleep(time_to_sleep)
      end

      return File.open(@path) do |file|
        if !pos.nil?
          file.pos = @pos
        end
        if args.nil?
          file.read
        else
          file.read(args)
        end
      end 
    end
  end
end
