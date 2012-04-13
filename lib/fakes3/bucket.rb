require 'builder'
require 'fakes3/s3_object'

module FakeS3
  class Bucket
    attr_accessor :name,:creation_date,:objects

    def initialize(name,creation_date,objects)
      @name = name
      @creation_date = creation_date
      @objects = []
      objects.each do |obj|
        @objects << obj
      end
    end

  end
end
