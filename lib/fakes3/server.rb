require 'time'
require 'webrick'
require 'webrick/https'
require 'openssl'
require 'securerandom'
require 'cgi'
require 'uri'
require 'fakes3/util'
require 'fakes3/file_store'
require 'fakes3/xml_adapter'
require 'fakes3/xml_parser'
require 'fakes3/bucket_query'
require 'fakes3/unsupported_operation'
require 'fakes3/errors'
require 'ipaddr'

module FakeS3
  class Request
    CREATE_BUCKET = "CREATE_BUCKET"
    LIST_BUCKETS = "LIST_BUCKETS"
    LS_BUCKET = "LS_BUCKET"
    HEAD = "HEAD"
    STORE = "STORE"
    COPY = "COPY"
    GET = "GET"
    GET_ACL = "GET_ACL"
    SET_ACL = "SET_ACL"
    MOVE = "MOVE"
    DELETE_OBJECT = "DELETE_OBJECT"
    DELETE_BUCKET = "DELETE_BUCKET"
    DELETE_OBJECTS = "DELETE_OBJECTS"

    attr_accessor :bucket, :object, :type, :src_bucket,
                  :src_object, :method, :webrick_request,
                  :path, :is_path_style, :query, :http_verb

    def inspect
      puts "-----Inspect FakeS3 Request"
      puts "Type: #{@type}"
      puts "Is Path Style: #{@is_path_style}"
      puts "Request Method: #{@method}"
      puts "Bucket: #{@bucket}"
      puts "Object: #{@object}"
      puts "Src Bucket: #{@src_bucket}"
      puts "Src Object: #{@src_object}"
      puts "Query: #{@query}"
      puts "-----Done"
    end
  end

  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server,store,hostname,cors_options)
      super(server)
      @store = store
      @hostname = hostname
      @port = server.config[:Port]
      @root_hostnames = [hostname,'localhost','s3.amazonaws.com','s3.localhost']

      # Here lies hard-coded defaults for CORS Configuration
      @cors_allow_origin = (cors_options['allow_origin'] or '*')
      @cors_allow_methods = (cors_options['allow_methods'] or 'PUT, POST, HEAD, GET, OPTIONS')
      @cors_preflight_allow_headers = (cors_options['preflight_allow_headers'] or 'Accept, Content-Type, Authorization, Content-Length, ETag, X-CSRF-Token, Content-Disposition')
      @cors_post_put_allow_headers = (cors_options['post_put_allow_headers'] or 'Authorization, Content-Length')
      @cors_expose_headers = (cors_options['expose_headers'] or 'ETag')
    end

    def validate_request(request)
      req = request.webrick_request
      return if req.nil?
      return if not req.header.has_key?('expect')
      req.continue if req.header['expect'].first=='100-continue'
    end

    def do_GET(request, response)
      s_req = normalize_request(request)

      case s_req.type
      when 'LIST_BUCKETS'
        response.status = 200
        response['Content-Type'] = 'application/xml'
        buckets = @store.buckets
        response.body = XmlAdapter.buckets(buckets)
      when 'LS_BUCKET'
        bucket_obj = @store.get_bucket(s_req.bucket)
        if bucket_obj
          response.status = 200
          response['Content-Type'] = "application/xml"
          query = {
            :marker => s_req.query["marker"] ? s_req.query["marker"].to_s : nil,
            :prefix => s_req.query["prefix"] ? s_req.query["prefix"].to_s : nil,
            :max_keys => s_req.query["max-keys"] ? s_req.query["max-keys"].to_i : nil,
            :delimiter => s_req.query["delimiter"] ? s_req.query["delimiter"].to_s : nil
          }
          bq = bucket_obj.query_for_range(query)
          response.body = XmlAdapter.bucket_query(bq)
        else
          response.status = 404
          response.body = XmlAdapter.error_no_such_bucket(s_req.bucket)
          response['Content-Type'] = "application/xml"
        end
      when 'GET_ACL'
        response.status = 200
        response.body = XmlAdapter.acl
        response['Content-Type'] = 'application/xml'
      when 'GET'
        real_obj = @store.get_object(s_req.bucket, s_req.object, request)
        if !real_obj
          response.status = 404
          response.body = XmlAdapter.error_no_such_key(s_req.object)
          response['Content-Type'] = "application/xml"
          response['Access-Control-Allow-Origin'] = @cors_allow_origin
          return
        end

        if_none_match = request["If-None-Match"]
        if if_none_match == "\"#{real_obj.md5}\"" or if_none_match == "*"
          response.status = 304
          return
        end

        if_modified_since = request["If-Modified-Since"]
        if if_modified_since
          time = Time.httpdate(if_modified_since)
          if time >= Time.iso8601(real_obj.modified_date)
            response.status = 304
            return
          end
        end

        response.status = 200
        response['Content-Type'] = real_obj.content_type

        if real_obj.content_encoding
          response.header['X-Content-Encoding'] = real_obj.content_encoding
          response.header['Content-Encoding'] = real_obj.content_encoding
        end

        response['Content-Disposition'] = real_obj.content_disposition ? real_obj.content_disposition : 'attachment'

        response['Last-Modified'] = Time.iso8601(real_obj.modified_date).httpdate
        response.header['ETag'] = "\"#{real_obj.md5}\""
        response['Accept-Ranges'] = "bytes"
        response['Last-Ranges'] = "bytes"
        response['Access-Control-Allow-Origin'] = @cors_allow_origin

        real_obj.custom_metadata.each do |header, value|
          response.header['x-amz-meta-' + header] = value
        end

        stat = File::Stat.new(real_obj.io.path)
        content_length = stat.size

        # Added Range Query support
        range = request.header["range"].first
        if range
          response.status = 206
          if range =~ /bytes=(\d*)-(\d*)/
            start = $1.to_i
            finish = $2.to_i
            finish_str = ""
            if finish == 0
              finish = content_length - 1
              finish_str = "#{finish}"
            else
              finish_str = finish.to_s
            end

            bytes_to_read = finish - start + 1
            response['Content-Range'] = "bytes #{start}-#{finish_str}/#{content_length}"
            real_obj.io.pos = start
            response.body = real_obj.io.read(bytes_to_read)
            return
          end
        end
        response['Content-Length'] = File::Stat.new(real_obj.io.path).size
        if s_req.http_verb == 'HEAD'
          response.body = ""
	        real_obj.io.close
        else
          response.body = real_obj.io
        end

        if real_obj.cache_control
          response['Cache-Control'] = real_obj.cache_control
        end
      end
    end

    def do_PUT(request, response)
      s_req = normalize_request(request)
      query = CGI::parse(request.request_uri.query || "")

      return do_multipartPUT(request, response) if query['uploadId'].first

      response.status = 200
      response.body = ""
      response['Content-Type'] = "text/xml"
      response['Access-Control-Allow-Origin'] = @cors_allow_origin

      case s_req.type
      when Request::COPY
        object = @store.copy_object(s_req.src_bucket, s_req.src_object, s_req.bucket, s_req.object, request)
        response.body = XmlAdapter.copy_object_result(object)
      when Request::STORE
        bucket_obj = @store.get_bucket(s_req.bucket)
        if !bucket_obj
          # Lazily create a bucket.  TODO fix this to return the proper error
          bucket_obj = @store.create_bucket(s_req.bucket)
        end

        real_obj = @store.store_object(bucket_obj, s_req.object, s_req.webrick_request)
        response.header['ETag'] = "\"#{real_obj.md5}\""
      when Request::CREATE_BUCKET
        @store.create_bucket(s_req.bucket)
      end
    end

    def do_multipartPUT(request, response)
      s_req = normalize_request(request)
      query = CGI::parse(request.request_uri.query)

      part_number   = query['partNumber'].first
      upload_id     = query['uploadId'].first
      part_name     = "#{upload_id}_#{s_req.object}_part#{part_number}"

      # store the part
      if s_req.type == Request::COPY
        real_obj = @store.copy_object(
          s_req.src_bucket, s_req.src_object,
          s_req.bucket    , part_name,
          request
        )

        response['Content-Type'] = "text/xml"
        response.body = XmlAdapter.copy_object_result real_obj
      else
        bucket_obj  = @store.get_bucket(s_req.bucket)
        if !bucket_obj
          bucket_obj = @store.create_bucket(s_req.bucket)
        end
        real_obj    = @store.store_object(
          bucket_obj, part_name,
          request
        )

        response.body   = ""
        response.header['ETag']  = "\"#{real_obj.md5}\""
      end

      response['Access-Control-Allow-Origin']   = @cors_allow_origin
      response['Access-Control-Allow-Headers']  = @cors_post_put_allow_headers
      response['Access-Control-Expose-Headers'] = @cors_expose_headers

      response.status = 200
    end

    def do_POST(request,response)
      if request.query_string === 'delete'
        return do_DELETE(request, response)
      end

      s_req = normalize_request(request)
      key   = request.query['key']
      query = CGI::parse(request.request_uri.query || "")

      if query.has_key?('uploads')
        upload_id = SecureRandom.hex

        response.body = <<-eos.strip
          <?xml version="1.0" encoding="UTF-8"?>
          <InitiateMultipartUploadResult>
            <Bucket>#{ s_req.bucket }</Bucket>
            <Key>#{ key }</Key>
            <UploadId>#{ upload_id }</UploadId>
          </InitiateMultipartUploadResult>
        eos
      elsif query.has_key?('uploadId')
        upload_id  = query['uploadId'].first
        bucket_obj = @store.get_bucket(s_req.bucket)
        real_obj   = @store.combine_object_parts(
          bucket_obj,
          upload_id,
          s_req.object,
          parse_complete_multipart_upload(request),
          request
        )

        response.body = XmlAdapter.complete_multipart_result real_obj
      elsif request.content_type =~ /^multipart\/form-data; boundary=(.+)/
        key = request.query['key']

        success_action_redirect = request.query['success_action_redirect']
        success_action_status   = request.query['success_action_status']

        filename = 'default'
        filename = $1 if request.body =~ /filename="(.*)"/
        key      = key.gsub('${filename}', filename)

        bucket_obj = @store.get_bucket(s_req.bucket) || @store.create_bucket(s_req.bucket)
        real_obj   = @store.store_object(bucket_obj, key, s_req.webrick_request)

        response['Etag'] = "\"#{real_obj.md5}\""

        if success_action_redirect
          object_params = [ [ :bucket, s_req.bucket ], [ :key, key ] ]
          location_uri = URI.parse(success_action_redirect)
          original_location_params = URI.decode_www_form(String(location_uri.query))
          location_uri.query = URI.encode_www_form(original_location_params + object_params)

          response.status      = 303
          response.body        = ""
          response['Location'] = location_uri.to_s
        else
          response.status = success_action_status || 204
          if response.status == "201"
            response.body = <<-eos.strip
              <?xml version="1.0" encoding="UTF-8"?>
              <PostResponse>
                <Location>http://#{s_req.bucket}.localhost:#{@port}/#{key}</Location>
                <Bucket>#{s_req.bucket}</Bucket>
                <Key>#{key}</Key>
                <ETag>#{response['Etag']}</ETag>
              </PostResponse>
            eos
          end
        end
      else
        raise WEBrick::HTTPStatus::BadRequest
      end

      response['Content-Type']                  = 'text/xml'
      response['Access-Control-Allow-Origin']   = @cors_allow_origin
      response['Access-Control-Allow-Headers']  = @cors_post_put_allow_headers
      response['Access-Control-Expose-Headers'] = @cors_expose_headers
    end

    def do_DELETE(request, response)
      s_req = normalize_request(request)

      case s_req.type
      when Request::DELETE_OBJECTS
        bucket_obj = @store.get_bucket(s_req.bucket)
        keys = XmlParser.delete_objects(s_req.webrick_request)
        @store.delete_objects(bucket_obj,keys,s_req.webrick_request)
      when Request::DELETE_OBJECT
        bucket_obj = @store.get_bucket(s_req.bucket)
        @store.delete_object(bucket_obj,s_req.object,s_req.webrick_request)
      when Request::DELETE_BUCKET
        @store.delete_bucket(s_req.bucket)
      end

      response.status = 204
      response.body = ""
    end

    def do_OPTIONS(request, response)
      super
      response['Access-Control-Allow-Origin']   = @cors_allow_origin
      response['Access-Control-Allow-Methods']  = @cors_allow_methods
      response['Access-Control-Allow-Headers']  = @cors_preflight_allow_headers
      response['Access-Control-Expose-Headers'] = @cors_expose_headers
    end

    private

    def normalize_delete(webrick_req, s_req)
      path = webrick_req.path
      path_len = path.size
      query = webrick_req.query
      if path == "/" and s_req.is_path_style
        # Probably do a 404 here
      else
        if s_req.is_path_style
          elems = path[1,path_len].split("/")
          s_req.bucket = elems[0]
        else
          elems = path.split("/")
        end

        if elems.size == 0
          if s_req.is_path_style
            s_req.type = Request::DELETE_OBJECTS
            s_req.query = query
            s_req.webrick_request = webrick_req
          else
            s_req.type = Request::DELETE_BUCKET
          end
        elsif elems.size == 1
          s_req.type = webrick_req.query_string == 'delete' ? Request::DELETE_OBJECTS : Request::DELETE_BUCKET
          s_req.query = query
          s_req.webrick_request = webrick_req
        else
          s_req.type = Request::DELETE_OBJECT
          object = elems[1,elems.size].join('/')
          s_req.object = object
        end
      end
    end

    def normalize_get(webrick_req, s_req)
      path = webrick_req.path
      path_len = path.size
      query = webrick_req.query
      if path == "/" and s_req.is_path_style
        s_req.type = Request::LIST_BUCKETS
      else
        if s_req.is_path_style
          elems = path[1,path_len].split("/")
          s_req.bucket = elems[0]
        else
          elems = path.split("/")
        end

        if elems.size < 2
          s_req.type = Request::LS_BUCKET
          s_req.query = query
        else
          if query["acl"] == ""
            s_req.type = Request::GET_ACL
          else
            s_req.type = Request::GET
          end
          object = elems[1,elems.size].join('/')
          s_req.object = object
        end
      end
    end

    def normalize_put(webrick_req, s_req)
      path = webrick_req.path
      path_len = path.size
      if path == "/"
        if s_req.bucket
          s_req.type = Request::CREATE_BUCKET
        end
      else
        if s_req.is_path_style
          elems = path[1,path_len].split("/")
          s_req.bucket = elems[0]
          if elems.size == 1
            s_req.type = Request::CREATE_BUCKET
          else
            if webrick_req.request_line =~ /\?acl/
              s_req.type = Request::SET_ACL
            else
              s_req.type = Request::STORE
            end
            s_req.object = elems[1,elems.size].join('/')
          end
        else
          if webrick_req.request_line =~ /\?acl/
            s_req.type = Request::SET_ACL
          else
            s_req.type = Request::STORE
          end
          s_req.object = webrick_req.path[1..-1]
        end
      end

      # TODO: also parse the x-amz-copy-source-range:bytes=first-last header
      # for multipart copy
      copy_source = webrick_req.header["x-amz-copy-source"]
      if copy_source and copy_source.size == 1
        copy_source = URI.unescape copy_source.first
        src_elems   = copy_source.split("/")
        root_offset = src_elems[0] == "" ? 1 : 0
        s_req.src_bucket = src_elems[root_offset]
        s_req.src_object = src_elems[1 + root_offset,src_elems.size].join("/")
        s_req.type = Request::COPY
      end

      s_req.webrick_request = webrick_req
    end

    def normalize_post(webrick_req,s_req)
      path = webrick_req.path
      path_len = path.size

      s_req.path = webrick_req.query['key']
      s_req.webrick_request = webrick_req

      if s_req.is_path_style
        elems = path[1, path_len].split("/")
        s_req.bucket = elems[0]
        s_req.object = elems[1..-1].join('/') if elems.size >= 2
      else
        s_req.object = path[1..-1]
      end
    end

    # This method takes a webrick request and generates a normalized FakeS3 request
    def normalize_request(webrick_req)
      host_header= webrick_req["Host"]
      host = host_header.split(':')[0]

      s_req = Request.new
      s_req.path = webrick_req.path
      s_req.is_path_style = true

      root_hostname = @root_hostnames.find { |hostname| host.end_with?(".#{hostname}") }
      if root_hostname
        s_req.bucket = host[0...-root_hostname.size - 1]
        s_req.is_path_style = false
      end

      s_req.http_verb = webrick_req.request_method

      case webrick_req.request_method
      when 'PUT'
        normalize_put(webrick_req,s_req)
      when 'GET','HEAD'
        normalize_get(webrick_req,s_req)
      when 'DELETE'
        normalize_delete(webrick_req,s_req)
      when 'POST'
        if webrick_req.query_string != 'delete'
          normalize_post(webrick_req,s_req)
        else
          normalize_delete(webrick_req,s_req)
        end
      else
        raise "Unknown Request"
      end

      validate_request(s_req)

      return s_req
    end

    def parse_complete_multipart_upload(request)
      parts_xml   = ""
      request.body { |chunk| parts_xml << chunk }

      # TODO: improve parsing xml
      parts_xml = parts_xml.scan(/<Part>.*?<\/Part>/m)

      parts_xml.collect do |xml|
        {
          number: xml[/<PartNumber>(\d+)<\/PartNumber>/, 1].to_i,
          etag:   FakeS3::Util.strip_before_and_after(xml[/\<ETag\>(.+)<\/ETag>/, 1], '"')
        }
      end
    end

    def dump_request(request)
      puts "----------Dump Request-------------"
      puts request.request_method
      puts request.path
      request.each do |k,v|
        puts "#{k}:#{v}"
      end
      puts "----------End Dump -------------"
    end
  end


  class Server
    def initialize(address, port, store, hostname, ssl_cert_path, ssl_key_path, extra_options={})
      @address = address
      @port = port
      @store = store
      @hostname = hostname
      @ssl_cert_path = ssl_cert_path
      @ssl_key_path = ssl_key_path
      @cors_options = extra_options[:cors_options] or {}
      webrick_config = {
        :BindAddress => @address,
        :Port => @port
      }
      if !@ssl_cert_path.to_s.empty?
        webrick_config.merge!(
          {
            :SSLEnable => true,
            :SSLCertificate => OpenSSL::X509::Certificate.new(File.read(@ssl_cert_path)),
            :SSLPrivateKey => OpenSSL::PKey::RSA.new(File.read(@ssl_key_path))
          }
        )
      end

      if extra_options[:quiet]
        webrick_config.merge!(
          :Logger => WEBrick::Log.new("/dev/null"),
          :AccessLog => []
        )
      end

      @server = WEBrick::HTTPServer.new(webrick_config)
    end

    def serve
      @server.mount "/", Servlet, @store, @hostname, @cors_options
      shutdown = proc { @server.shutdown }
      trap "INT", &shutdown
      trap "TERM", &shutdown
      @server.start
    end

    def shutdown
      @server.shutdown
    end
  end
end
