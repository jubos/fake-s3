module FakeS3
  class S3Object
    attr_accessor :name,:size,:creation_date,:md5,:io,:content_type
  end
end
