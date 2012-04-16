module FakeS3
  class S3Object
    include Comparable
    attr_accessor :name,:size,:creation_date,:md5,:io,:content_type

    # Sort by the object's name
    def <=>(object)
      @name <=> object.name
    end
  end
end
