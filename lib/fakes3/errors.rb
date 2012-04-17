module FakeS3
  class FakeS3Exception < RuntimeError
    attr_accessor :resource,:request_id

    def self.metaclass; class << self; self; end; end

    def self.traits(*arr)
      return @traits if arr.empty?
      attr_accessor *arr

      arr.each do |a|
        metaclass.instance_eval do
          define_method( a ) do |val|
            @traits ||= {}
            @traits[a] = val
          end
        end
      end

      class_eval do
        define_method( :initialize ) do
          self.class.traits.each do |k,v|
            instance_variable_set("@#{k}", v)
          end
        end
      end
    end

    traits :message,:http_status

    def code
      self.class.to_s
    end
  end

  class NoSuchBucket < FakeS3Exception
    message "The bucket you tried to delete is not empty."
    http_status "404"
  end

  class BucketNotEmpty < FakeS3Exception
    message "The bucket you tried to delete is not empty."
    http_status "409"
  end

end
