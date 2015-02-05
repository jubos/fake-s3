require 'builder'
require 'thread'
require 'fakes3/s3_object'
require 'fakes3/sorted_object_list'

module FakeS3
  class Bucket
    attr_accessor :name,:creation_date,:objects

    def initialize(name,creation_date,objects)
      @name = name
      @creation_date = creation_date
      @objects = SortedObjectList.new
      objects.each do |obj|
        @objects.add(obj)
      end
      @mutex = Mutex.new
    end

    def find(object_name)
      @mutex.synchronize do
        @objects.find(object_name)
      end
    end

    def add(object)
      # Unfortunately have to synchronize here since the our SortedObjectList
      # not thread safe. Probably can get finer granularity if performance is
      # important
      @mutex.synchronize do
        @objects.add(object)
      end
    end

    def remove(object)
      @mutex.synchronize do
        @objects.remove(object)
      end
    end

    def query_for_range(options)
      marker = options[:marker]
      prefix = options[:prefix]
      max_keys = options[:max_keys] || 1000
      delimiter = options[:delimiter]

      match_set = nil
      @mutex.synchronize do
        match_set = @objects.list(options)
      end

      bq = BucketQuery.new
      bq.bucket = self
      bq.marker = marker
      bq.prefix = prefix
      bq.max_keys = max_keys
      bq.delimiter = delimiter
      bq.matches = match_set.matches
      bq.is_truncated = match_set.is_truncated
      bq.common_prefixes = match_set.common_prefixes
      return bq
    end

  end
end
