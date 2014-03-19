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
        objects = objects_for_bucket(bucket_name)
        bucket_obj = Bucket.new(bucket_name,Time.now,objects)
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
        real_obj.custom_metadata = metadata.fetch(:custom_metadata) { {} }
        real_obj.storage_class = metadata[:storage_class]
        real_obj.state = metadata[:state]
        real_obj.days = metadata[:days]
        return real_obj
      rescue
        puts $!
        $!.backtrace.each { |line| puts line }
        return nil
      end
    end

    def object_metadata(bucket,object)
    end

    def copy_object(src_bucket_name,src_name,dst_bucket_name,dst_name,request)
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

      if src_bucket_name != dst_bucket_name || src_name != dst_name
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
      end

      metadata_directive = request.header["x-amz-metadata-directive"].first
      if metadata_directive == "REPLACE"
        metadata_struct = create_metadata(content,request)
        File.open(metadata,'w') do |f|
          f << YAML::dump(metadata_struct)
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

        # TODO put a tmpfile here first and mv it over at the end

        match=request.content_type.match(/^multipart\/form-data; boundary=(.+)/)
        boundary = match[1] if match
        if boundary
          boundary = WEBrick::HTTPUtils::dequote(boundary)
          filedata = WEBrick::HTTPUtils::parse_form_data(request.body, boundary)
          raise HTTPStatus::BadRequest if filedata['file'].empty?
          File.open(content, 'wb') do |f|
            f << filedata['file']
          end
        else
          File.open(content,'wb') do |f|
            request.body do |chunk|
              f << chunk
            end
          end
        end
        metadata_struct = create_metadata(content,request)
        File.open(metadata,'w') do |f|
          f << YAML::dump(metadata_struct)
        end

        obj = S3Object.new
        obj.name = object_name
        obj.md5 = metadata_struct[:md5]
        obj.content_type = metadata_struct[:content_type]
        obj.size = metadata_struct[:size]
        obj.modified_date = metadata_struct[:modified_date]
        obj.storage_class = metadata_struct[:storage_class]
        obj.custom_metadata = metadata_struct[:custom_metadata]
        obj.state = metadata_struct[:state]

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

    def create_metadata(content,request)
      metadata = {}
      metadata[:md5] = Digest::MD5.file(content).hexdigest
      metadata[:content_type] = request.header["content-type"].first
      metadata[:size] = File.size(content)
      metadata[:modified_date] = File.mtime(content).utc.iso8601()
      metadata[:storage_class] = S3Object::StorageClass::STANDARD
      metadata[:state] = S3Object::State::IN_STANDARD

      request.header.each do |key, value|
        match = /^x-amz-meta-(.*)$/.match(key)
        if match
          metadata[:custom_metadata][match[1]] = value.join(', ')
        end
      end      
      metadata
    end

    def list_all
      list = [%w(BUCKET OBJECT_NAME STORAGE_CLASS STATE)]
      buckets.each do |bucket|
        bucket.objects.list({}).matches.collect(&:name).each do |object_name|
          object = get_object bucket.name, object_name, nil
          list << [bucket.name, object.name, object.storage_class, object.state]
        end
      end
      maxes = [0, 0, 0, 0]
      list.each{|row| row.each_with_index{|col, index| maxes[index] = [col.size, maxes[index]].max}}
      maxes.map!{|e| e + 1}
      list.map do |row|
        index = -1
        row.map{|val| val.ljust(maxes[index+=1])}.join "\t"
      end.join "\n"
    end

    def to_glacier(bucket, object_name)
      obj = get_bucket(bucket).find(object_name)
      obj.storage_class = S3Object::StorageClass::GLACIER
      obj.state = S3Object::State::IN_GLACIER
      metadata = load_metadata bucket, object_name
      metadata[:storage_class] = obj.storage_class
      metadata[:state] = obj.state
      store_metadata(bucket, object_name, metadata)
    end

    def to_standard(bucket, object_name)
      obj = get_bucket(bucket).find(object_name)
      obj.storage_class = S3Object::StorageClass::STANDARD
      obj.state = S3Object::State::IN_STANDARD
      metadata = load_metadata bucket, object_name
      metadata[:storage_class] = obj.storage_class
      metadata[:state] = obj.state
      store_metadata(bucket, object_name, metadata)
    end

    def to_restored_from_glacier(bucket, object_name)
      obj = get_bucket(bucket).find(object_name)
      obj.storage_class = S3Object::StorageClass::GLACIER
      obj.state = S3Object::State::RESTORED
      metadata = load_metadata bucket, object_name
      metadata[:storage_class] = obj.storage_class
      metadata[:state] = obj.state
      store_metadata(bucket, object_name, metadata)
    end

    def to_restored_expired(bucket, object_name)
      obj = get_bucket(bucket).find(object_name)
      obj.storage_class = S3Object::StorageClass::GLACIER
      obj.state = S3Object::State::RESTORED_COPY_EXPIRED
      metadata = load_metadata bucket, object_name
      metadata[:storage_class] = obj.storage_class
      metadata[:state] = obj.state
      store_metadata(bucket, object_name, metadata)
    end

    def to_restoring_in_progress(bucket, object_name, days=1)
      obj = get_bucket(bucket).find(object_name)
      obj.storage_class = S3Object::StorageClass::GLACIER
      obj.state = S3Object::State::RESTORING
      obj.days = days
      metadata = load_metadata bucket, object_name
      metadata[:storage_class] = obj.storage_class
      metadata[:state] = obj.state
      metadata[:days] = days
      store_metadata(bucket, object_name, metadata)
    end

    private

    def load_metadata(bucket, object_name)
      YAML.load(File.open(metadata_file(bucket, object_name),'rb'))
    end

    def store_metadata(bucket, object_name, metadata)
      File.open(metadata_file(bucket, object_name),'w') do |f|
        f << YAML::dump(metadata)
      end
    end

    def metadata_file(bucket, object_name)
      obj_root = File.join(@root,bucket,object_name,SHUCK_METADATA_DIR)
       File.join(obj_root, "metadata")
    end

    def objects_for_bucket(bucket_name)
      bucket_dir = File.join @root, bucket_name
      discover_object_names(bucket_dir, '').map do |object_name|
        get_object(bucket_name, object_name, nil)
      end
    end

    def discover_object_names(dir, prefix)
      names = []
      metadata_dir = File.join dir,SHUCK_METADATA_DIR
      if Dir.exists? metadata_dir
        names << prefix
      end
      Dir[File.join(dir,'*')].select{|file| File.directory? file}.each do |dir|
        dir_name = File.basename dir
        new_prefix = prefix.empty? ? dir_name : "#{prefix}/#{dir_name}"
        names += discover_object_names(dir, new_prefix)
      end
      names
    end
  end
end
