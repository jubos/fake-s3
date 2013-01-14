require 'set'
module FakeS3
  class S3MatchSet
    attr_accessor :matches,:is_truncated,:common_prefixes
    def initialize
      @matches = []
      @is_truncated = false
      @common_prefixes = []
    end
  end

  # This class has some of the semantics necessary for how buckets can return
  # their items
  #
  # It is currently implemented naively as a sorted set + hash If you are going
  # to try to put massive lists inside buckets and ls them, you will be sorely
  # disappointed about this performance.
  class SortedObjectList

    def initialize
      @sorted_set = SortedSet.new
      @object_map = {}
      @mutex = Mutex.new
    end

    def count
      @sorted_set.count
    end

    def find(object_name)
      @object_map[object_name]
    end

    # Add an S3 object into the sorted list
    def add(s3_object)
      return if !s3_object

      @object_map[s3_object.name] = s3_object
      @sorted_set << s3_object
    end

    def remove(s3_object)
      return if !s3_object

      @object_map.delete(s3_object.name)
      @sorted_set.delete(s3_object)
    end

    # Return back a set of matches based on the passed in options
    #
    # options:
    #
    # :marker : a string to start the lexographical search (it is not included
    #           in the result)
    # :max_keys  : a maximum number of results
    # :prefix    : a string to filter the results by
    # :delimiter : not supported yet
    def list(options)
      marker = options[:marker]
      prefix = options[:prefix]
      max_keys = options[:max_keys] || 1000
      delimiter = options[:delimiter]

      ms = S3MatchSet.new

      marker_found = true
      pseudo = nil
      if marker
        marker_found = false
        if !@object_map[marker]
          pseudo = S3Object.new
          pseudo.name = marker
          @sorted_set << pseudo
        end
      end

      if delimiter
        if prefix
          base_prefix = prefix
        else
          base_prefix = ""
        end
        prefix_offset = base_prefix.length
      end

      count = 0
      last_chunk = nil
      @sorted_set.each do |s3_object|
        if marker_found && (!prefix or s3_object.name.index(prefix) == 0)
          if delimiter
            name = s3_object.name
            remainder = name.slice(prefix_offset, name.length)
            chunks = remainder.split(delimiter, 2)
            if chunks.length > 1
              if (last_chunk != chunks[0])
                # "All of the keys rolled up in a common prefix count as
                # a single return when calculating the number of
                # returns. See MaxKeys."
                # (http://awsdocs.s3.amazonaws.com/S3/latest/s3-api.pdf)
                count += 1
                if count <= max_keys
                  ms.common_prefixes << base_prefix + chunks[0] + delimiter
                  last_chunk = chunks[0]
                else
                  is_truncated = true
                  break
                end
              end

              # Continue to the next key, since this one has a
              # delimiter.
              next
            end
          end

          count += 1
          if count <= max_keys
            ms.matches << s3_object
          else
            is_truncated = true
            break
          end
        end

        if marker and marker == s3_object.name
          marker_found = true
        end
      end

      if pseudo
        @sorted_set.delete(pseudo)
      end

      return ms
    end
  end
end
