module FakeS3
  class BucketQuery
    attr_accessor :prefix,:matches,:marker,:max_keys,
                  :delimiter,:bucket,:is_truncated,:common_prefixes

    # Syntactic sugar
    def is_truncated?
      @is_truncated
    end
  end
end
