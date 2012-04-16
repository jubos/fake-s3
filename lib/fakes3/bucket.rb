require 'builder'
require 'thread'
require 'fakes3/s3_object'
require 'fakes3/red_black_tree'

module FakeS3
  class Bucket
    attr_accessor :name,:creation_date,:objects

    def initialize(name,creation_date,objects)
      @name = name
      @creation_date = creation_date
      @objects = SortedSet.new
      @objects = RedBlackTree.new
      objects.each do |obj|
        @objects.add(obj)
      end
      @mutex = Mutex.new
    end

    def <<(object)
      # Unfortunately have to synchronize here since the RB Tree is not thread
      # safe. Probably can get finer granularity if performance is important
      @mutex.synchronize do
        exists = @objects.search(object.name)
        if exists.nil?
          @objects.add(object.name,object)
        end
      end
    end

    def delete(object_name)
      @objects.delete_via_key(object_name)
    end

    def query_for_range(options)
      marker = options[:marker]
      prefix = options[:prefix]
      max_keys = options[:max_keys] || 1000
      delimiter = options[:delimiter]

      matches = []
      is_truncated = false

      @mutex.synchronize do
        matches, is_truncated = @objects.search_for_range(
          marker,prefix,max_keys,delimiter)
      end

      bq = BucketQuery.new
      bq.bucket = self
      bq.marker = marker
      bq.prefix = prefix
      bq.max_keys = max_keys
      bq.delimiter = delimiter
      bq.matches = matches
      bq.is_truncated = is_truncated
      return bq
    end

  end
end
