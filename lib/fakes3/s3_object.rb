module FakeS3
  class S3Object
    include Comparable
    attr_accessor :name,:size,:creation_date,:modified_date,:md5,:io,:content_type,:custom_metadata

    def hash
      @name.hash
    end

    def eql?(object)
      @name == object.name
    end

    # Sort by the object's name
    def <=>(object)
      @name <=> object.name
    end
  end
end
