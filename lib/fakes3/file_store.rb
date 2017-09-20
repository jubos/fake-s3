require 'fileutils'
require 'time'
require 'fakes3/s3_object'
require 'fakes3/bucket'
require 'fakes3/rate_limitable_file'
require 'digest/md5'
require 'yaml'

module FakeS3
  class FileStore
    FAKE_S3_METADATA_DIR = ".fakes3_metadataFFF"

    # S3 clients with overly strict date parsing fails to parse ISO 8601 dates
    # without any sub second precision (e.g. jets3t v0.7.2), and the examples
    # given in the official AWS S3 documentation specify three (3) decimals for
    # sub second precision.
    SUBSECOND_PRECISION = 3

    def initialize(root, quiet_mode)
      @root = root
      @buckets = []
      @bucket_hash = {}
      @quiet_mode = quiet_mode
      Dir[File.join(root,"*")].each do |bucket|
        bucket_name = File.basename(bucket)
        bucket_obj = Bucket.new(bucket_name,Time.now,[])
        @buckets << bucket_obj
        @bucket_hash[bucket_name] = bucket_obj
      end
    end

    # Pass a rate limit in bytes per second
    def rate_limit=(rate_limit)
      if rate_limit.is_a?(String)
        if rate_limit =~ /^(\d+)$/
          RateLimitableFile.rate_limit = rate_limit.to_i
        elsif rate_limit =~ /^(.*)K$/
          RateLimitableFile.rate_limit = $1.to_f * 1000
        elsif rate_limit =~ /^(.*)M$/
          RateLimitableFile.rate_limit = $1.to_f * 1000000
        elsif rate_limit =~ /^(.*)G$/
          RateLimitableFile.rate_limit = $1.to_f * 1000000000
        else
          raise "Invalid Rate Limit Format: Valid values include (1000,10K,1.1M)"
        end
      else
        RateLimitableFile.rate_limit = nil
      end
    end

    def buckets
      @buckets
    end

    def get_bucket_folder(bucket)
      File.join(@root, bucket.name)
    end

    def get_bucket(bucket)
      @bucket_hash[bucket]
    end

    def create_bucket(bucket)
      FileUtils.mkdir_p(File.join(@root, bucket))
      bucket_obj = Bucket.new(bucket, Time.now, [])
      if !@bucket_hash[bucket]
        @buckets << bucket_obj
        @bucket_hash[bucket] = bucket_obj
      end
      bucket_obj
    end

    def delete_bucket(bucket_name)
      bucket = get_bucket(bucket_name)
      raise NoSuchBucket if !bucket
      raise BucketNotEmpty if bucket.objects.count > 0
      FileUtils.rm_r(get_bucket_folder(bucket))
      @bucket_hash.delete(bucket_name)
    end

    def get_object(bucket, object_name, request)
      begin
        real_obj = S3Object.new
        obj_root = File.join(@root,bucket,object_name,FAKE_S3_METADATA_DIR)
        metadata = File.open(File.join(obj_root, "metadata")) { |file| YAML::load(file) }
        real_obj.name = object_name
        real_obj.md5 = metadata[:md5]
        real_obj.content_type = request.query['response-content-type'] ||
          metadata.fetch(:content_type) { "application/octet-stream" }
        real_obj.content_disposition = request.query['response-content-disposition'] ||
          metadata[:content_disposition]
        real_obj.content_encoding = metadata.fetch(:content_encoding) # if metadata.fetch(:content_encoding)
        real_obj.io = RateLimitableFile.open(File.join(obj_root, "content"), 'rb')
        real_obj.size = metadata.fetch(:size) { 0 }
        real_obj.creation_date = File.ctime(obj_root).utc.iso8601(SUBSECOND_PRECISION)
        real_obj.modified_date = metadata.fetch(:modified_date) do
          File.mtime(File.join(obj_root, "content")).utc.iso8601(SUBSECOND_PRECISION)
        end
        real_obj.cache_control = metadata[:cache_control]
        real_obj.custom_metadata = metadata.fetch(:custom_metadata) { {} }
        return real_obj
      rescue
        unless @quiet_mode
          puts $!
          $!.backtrace.each { |line| puts line }
        end
        return nil
      end
    end

    def object_metadata(bucket, object)
    end

    def copy_object(src_bucket_name, src_name, dst_bucket_name, dst_name, request)
      src_root = File.join(@root,src_bucket_name,src_name,FAKE_S3_METADATA_DIR)
      src_metadata_filename = File.join(src_root, "metadata")
      src_metadata = YAML.load(File.open(src_metadata_filename, 'rb').read)
      src_content_filename = File.join(src_root, "content")

      dst_filename= File.join(@root,dst_bucket_name,dst_name)
      FileUtils.mkdir_p(dst_filename)

      metadata_dir = File.join(dst_filename,FAKE_S3_METADATA_DIR)
      FileUtils.mkdir_p(metadata_dir)

      content = File.join(metadata_dir, "content")
      metadata = File.join(metadata_dir, "metadata")

      if src_bucket_name != dst_bucket_name || src_name != dst_name
        File.open(content, 'wb') do |f|
          File.open(src_content_filename, 'rb') do |input|
            f << input.read
          end
        end

        File.open(metadata,'w') do |f|
          File.open(src_metadata_filename,'r') do |input|
            f << input.read
          end
        end
      end

      metadata_directive = request.header["x-amz-metadata-directive"].first
      if metadata_directive == "REPLACE"
        metadata_struct = create_metadata(content, request)
        File.open(metadata,'w') do |f|
          f << YAML::dump(metadata_struct)
        end
      end

      src_bucket = get_bucket(src_bucket_name) || create_bucket(src_bucket_name)
      dst_bucket = get_bucket(dst_bucket_name) || create_bucket(dst_bucket_name)

      obj = S3Object.new
      obj.name = dst_name
      obj.md5 = src_metadata[:md5]
      obj.content_type = src_metadata[:content_type]
      obj.content_disposition = src_metadata[:content_disposition]
      obj.content_encoding = src_metadata[:content_encoding] # if src_metadata[:content_encoding]
      obj.size = src_metadata[:size]
      obj.modified_date = src_metadata[:modified_date]
      obj.cache_control = src_metadata[:cache_control]

      src_bucket.find(src_name)
      dst_bucket.add(obj)
      return obj
    end

    def store_object(bucket, object_name, request)
      filedata = ""

      # TODO put a tmpfile here first and mv it over at the end
      content_type = request.content_type || ""

      match = content_type.match(/^multipart\/form-data; boundary=(.+)/)
      boundary = match[1] if match
      if boundary
        boundary = WEBrick::HTTPUtils::dequote(boundary)
        form_data = WEBrick::HTTPUtils::parse_form_data(request.body, boundary)

        if form_data['file'] == nil || form_data['file'] == ""
          raise WEBrick::HTTPStatus::BadRequest
        end

        filedata = form_data['file']
      else
        request.body { |chunk| filedata << chunk }
      end

      do_store_object(bucket, object_name, filedata, request)
    end

    def do_store_object(bucket, object_name, filedata, request)
      begin
        filename = File.join(@root, bucket.name, object_name)
        FileUtils.mkdir_p(filename)

        metadata_dir = File.join(filename, FAKE_S3_METADATA_DIR)
        FileUtils.mkdir_p(metadata_dir)

        content = File.join(filename, FAKE_S3_METADATA_DIR, "content")
        metadata = File.join(filename, FAKE_S3_METADATA_DIR, "metadata")

        File.open(content,'wb') { |f| f << filedata }

        metadata_struct = create_metadata(content, request)
        File.open(metadata,'w') do |f|
          f << YAML::dump(metadata_struct)
        end

        obj = S3Object.new
        obj.name = object_name
        obj.md5 = metadata_struct[:md5]
        obj.content_type = metadata_struct[:content_type]
        obj.content_disposition = metadata_struct[:content_disposition]
        obj.content_encoding = metadata_struct[:content_encoding] # if metadata_struct[:content_encoding]
        obj.size = metadata_struct[:size]
        obj.modified_date = metadata_struct[:modified_date]
        obj.cache_control = metadata_struct[:cache_control]

        bucket.add(obj)
        return obj
      rescue
        unless @quiet_mode
          puts $!
          $!.backtrace.each { |line| puts line }
        end
        return nil
      end
    end

    def combine_object_parts(bucket, upload_id, object_name, parts, request)
      upload_path   = File.join(@root, bucket.name)
      base_path     = File.join(upload_path, "#{upload_id}_#{object_name}")

      complete_file = ""
      chunk         = ""
      part_paths    = []

      parts.sort_by { |part| part[:number] }.each do |part|
        part_path    = "#{base_path}_part#{part[:number]}"
        content_path = File.join(part_path, FAKE_S3_METADATA_DIR, 'content')

        File.open(content_path, 'rb') { |f| chunk = f.read }
        etag = Digest::MD5.hexdigest(chunk)

        raise new Error "invalid file chunk" unless part[:etag] == etag
        complete_file << chunk
        part_paths    << part_path
      end

      object = do_store_object(bucket, object_name, complete_file, request)

      # clean up parts
      part_paths.each do |path|
        FileUtils.remove_dir(path)
      end

      object
    end

    def delete_object(bucket,object_name,request)
      begin
        filename = File.join(@root,bucket.name,object_name)
        FileUtils.rm_rf(filename)
        object = bucket.find(object_name)
        bucket.remove(object)
      rescue
        puts $!
        $!.backtrace.each { |line| puts line }
        return nil
      end
    end

    def delete_objects(bucket, objects, request)
      begin
        filenames = []
        objects.each do |object_name|
          filenames << File.join(@root,bucket.name,object_name)
          object = bucket.find(object_name)
          bucket.remove(object)
        end

        FileUtils.rm_rf(filenames)
      rescue
        puts $!
        $!.backtrace.each { |line| puts line }
        return nil
      end
    end

    # TODO: abstract getting meta data from request.
    def create_metadata(content, request)
      metadata = {}
      metadata[:md5] = Digest::MD5.file(content).hexdigest
      metadata[:content_type] = request.header["content-type"].first
      if request.header['content-disposition']
        metadata[:content_disposition] = request.header['content-disposition'].first
      end

      if request.header['cache-control']
        metadata[:cache_control] = request.header['cache-control'].first
      end

      content_encoding = request.header["content-encoding"].first
      metadata[:content_encoding] = content_encoding
      #if content_encoding
      #  metadata[:content_encoding] = content_encoding
      #end
      metadata[:size] = File.size(content)
      metadata[:modified_date] = File.mtime(content).utc.iso8601(SUBSECOND_PRECISION)
      metadata[:amazon_metadata] = {}
      metadata[:custom_metadata] = {}

      # Add custom metadata from the request header
      request.header.each do |key, value|
        match = /^x-amz-([^-]+)-(.*)$/.match(key)
        next unless match
        if match[1].eql?('meta') && (match_key = match[2])
          metadata[:custom_metadata][match_key] = value.join(', ')
          next
        end
        metadata[:amazon_metadata][key.gsub(/^x-amz-/, '')] = value.join(', ')
      end
      return metadata
    end
  end
end
