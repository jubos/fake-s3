module FakeS3
  class S3Object
    include Comparable
    attr_accessor :name,:size,:creation_date,:modified_date,:md5,:io,:content_type, :storage_class, :state, :days, :custom_metadata
    module StorageClass
      STANDARD = 'STANDARD'
      REDUCED_REDUNDANCY = 'REDUCED_REDUNDANCY'
      GLACIER = 'GLACIER'
    end
    module State
      IN_STANDARD = 'IN_STANDARD'
      IN_GLACIER = 'IN_GLACIER'
      RESTORING = 'RESTORING'
      RESTORED = 'RESTORED'
      RESTORED_COPY_EXPIRED = 'RESTORED_COPY_EXPIRED'
    end

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
