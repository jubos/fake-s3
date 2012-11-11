require 'fileutils'
require 'time'
require 'fakes3/s3_object'
require 'fakes3/bucket'
require 'fakes3/rate_limitable_file'
require 'digest/md5'
require 'yaml'

module FakeS3
  class FileStore
    SHUCK_METADATA_DIR = ".fakes3_metadataFFF"

    def initialize(root)
      @root = root
      @buckets = []
      @bucket_hash = {}
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
      File.join(@root,bucket.name)
    end

    def get_bucket(bucket)
      @bucket_hash[bucket]
    end

    def create_bucket(bucket)
      FileUtils.mkdir_p(File.join(@root,bucket))
      bucket_obj = Bucket.new(bucket,Time.now,[])
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

    def get_object(bucket,object_name, request)
      begin
        real_obj = S3Object.new
        obj_root = File.join(@root,bucket,object_name,SHUCK_METADATA_DIR)
        metadata = YAML.load(File.open(File.join(obj_root,"metadata"),'rb'))
        real_obj.name = object_name
        real_obj.md5 = metadata[:md5]
        real_obj.content_type = metadata.fetch(:content_type) { "application/octet-stream" }
        #real_obj.io = File.open(File.join(obj_root,"content"),'rb')
        real_obj.io = RateLimitableFile.open(File.join(obj_root,"content"),'rb')
        real_obj.size = metadata.fetch(:size) { 0 }
        real_obj.creation_date = File.ctime(obj_root).iso8601()
        real_obj.modified_date = metadata.fetch(:modified_date) { File.mtime(File.join(obj_root,"content")).iso8601() }
        return real_obj
      rescue
        puts $!
        $!.backtrace.each { |line| puts line }
        return nil
      end
    end

    def object_metadata(bucket,object)
    end

    def copy_object(src_bucket_name,src_name,dst_bucket_name,dst_name)
      src_root = File.join(@root,src_bucket_name,src_name,SHUCK_METADATA_DIR)
      src_metadata_filename = File.join(src_root,"metadata")
      src_metadata = YAML.load(File.open(src_metadata_filename,'rb').read)
      src_content_filename = File.join(src_root,"content")

      dst_filename= File.join(@root,dst_bucket_name,dst_name)
      FileUtils.mkdir_p(dst_filename)

      metadata_dir = File.join(dst_filename,SHUCK_METADATA_DIR)
      FileUtils.mkdir_p(metadata_dir)

      content = File.join(metadata_dir,"content")
      metadata = File.join(metadata_dir,"metadata")

      File.open(content,'wb') do |f|
        File.open(src_content_filename,'rb') do |input|
          f << input.read
        end
      end

      File.open(metadata,'w') do |f|
        File.open(src_metadata_filename,'r') do |input|
          f << input.read
        end
      end

      src_bucket = self.get_bucket(src_bucket_name)
      dst_bucket = self.get_bucket(dst_bucket_name)

      obj = S3Object.new
      obj.name = dst_name
      obj.md5 = src_metadata[:md5]
      obj.content_type = src_metadata[:content_type]
      obj.size = src_metadata[:size]
      obj.modified_date = src_metadata[:modified_date]

      src_obj = src_bucket.find(src_name)
      dst_bucket.add(obj)
      src_bucket.remove(src_obj)
      return obj
    end

    def store_object(bucket,object_name,request)
      begin
        filename = File.join(@root,bucket.name,object_name)
        FileUtils.mkdir_p(filename)

        metadata_dir = File.join(filename,SHUCK_METADATA_DIR)
        FileUtils.mkdir_p(metadata_dir)

        content = File.join(filename,SHUCK_METADATA_DIR,"content")
        metadata = File.join(filename,SHUCK_METADATA_DIR,"metadata")

        md5 = Digest::MD5.new
        # TODO put a tmpfile here first and mv it over at the end
        
        match=request.content_type.match(/^multipart\/form-data; boundary=(.+)/)
      	boundary = match[1] if match
        if boundary
          boundary = WEBrick::HTTPUtils::dequote(boundary)
          filedata = WEBrick::HTTPUtils::parse_form_data(request.body, boundary)
          raise HTTPStatus::BadRequest if filedata['file'].empty?
          File.open(content, 'wb') do |f|
            f<<filedata['file']
            md5<<filedata['file']
          end
        else
          File.open(content,'wb') do |f|
            request.body do |chunk|
              f << chunk
              md5 << chunk
            end
          end
        end
        metadata_struct = {}
        metadata_struct[:md5] = md5.hexdigest
        metadata_struct[:content_type] = request.header["content-type"].first
        metadata_struct[:size] = File.size(content)
        metadata_struct[:modified_date] = File.mtime(content).iso8601()

        File.open(metadata,'w') do |f|
          f << YAML::dump(metadata_struct)
        end

        obj = S3Object.new
        obj.name = object_name
        obj.md5 = metadata_struct[:md5]
        obj.content_type = metadata_struct[:content_type]
        obj.size = metadata_struct[:size]
        obj.modified_date = metadata_struct[:modified_date]

        bucket.add(obj)
        return obj
      rescue
        puts $!
        $!.backtrace.each { |line| puts line }
        return nil
      end
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
  end
end
