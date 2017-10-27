module FakeS3
  class S3Object
    include Comparable
    attr_accessor :name,:size,:creation_date,:modified_date,:md5,:io,:content_type,:content_disposition,:content_encoding,:custom_metadata,:cache_control

    def hash
      @name.hash
    end

    def eql?(object)
      object.is_a?(self.class) ? (@name == object.name) : false
    end

    # Sort by the object's name
    def <=>(object)
      object.is_a?(self.class) ? (@name <=> object.name) : nil
    end
  end
end
