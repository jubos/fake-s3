require 'builder'
require 'time'

module FakeS3
  class XmlAdapter
    def self.buckets(bucket_objects)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.ListAllMyBucketsResult(:xmlns => "http://s3.amazonaws.com/doc/2006-03-01/") { |lam|
        lam.Owner { |owner|
          owner.ID("123")
          owner.DisplayName("FakeS3")
        }
        lam.Buckets { |buckets|
          bucket_objects.each do |bucket|
            buckets.Bucket do |b|
              b.Name(bucket.name)
              b.CreationDate(bucket.creation_date.strftime("%Y-%m-%dT%H:%M:%S.000Z"))
            end
          end
        }
      }
      output
    end

    def self.error(error)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.Error { |err|
        err.Code(error.code)
        err.Message(error.message)
        err.Resource(error.resource)
        err.RequestId(1)
      }
      output
    end

    # <?xml version="1.0" encoding="UTF-8"?>
    #<Error>
    #  <Code>NoSuchKey</Code>
    #  <Message>The resource you requested does not exist</Message>
    #  <Resource>/mybucket/myfoto.jpg</Resource>
    #  <RequestId>4442587FB7D0A2F9</RequestId>
    #</Error>
    #
    def self.error_no_such_bucket(name)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.Error { |err|
        err.Code("NoSuchBucket")
        err.Message("The resource you requested does not exist")
        err.Resource(name)
        err.RequestId(1)
      }
      output
    end

    def self.error_bucket_not_empty(name)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.Error { |err|
        err.Code("BucketNotEmpty")
        err.Message("The bucket you tried to delete is not empty.")
        err.Resource(name)
        err.RequestId(1)
      }
      output
    end

    def self.error_no_such_key(name)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.Error { |err|
        err.Code("NoSuchKey")
        err.Message("The specified key does not exist")
        err.Key(name)
        err.RequestId(1)
        err.HostId(2)
      }
      output
    end

    def self.bucket(bucket)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.ListBucketResult(:xmlns => "http://s3.amazonaws.com/doc/2006-03-01/") { |lbr|
        lbr.Name(bucket.name)
        lbr.Prefix
        lbr.Marker
        lbr.MaxKeys("1000")
        lbr.IsTruncated("false")
      }
      output
    end

    # A bucket query gives back the bucket along with contents
    #  <Contents>
    #<Key>Nelson</Key>
#    <LastModified>2006-01-01T12:00:00.000Z</LastModified>
#    <ETag>&quot;828ef3fdfa96f00ad9f27c383fc9ac7f&quot;</ETag>
#    <Size>5</Size>
#    <StorageClass>STANDARD</StorageClass>
#    <Owner>
#      <ID>bcaf161ca5fb16fd081034f</ID>
#      <DisplayName>webfile</DisplayName>
#     </Owner>
#    </Contents>

    def self.append_objects_to_list_bucket_result(lbr,objects)
      return if objects.nil? or objects.size == 0

      if objects.index(nil)
        require 'ruby-debug'
        Debugger.start
        debugger
      end

      objects.each do |s3_object|
        lbr.Contents { |contents|
          contents.Key(s3_object.name)
          contents.LastModified(s3_object.modified_date)
          contents.ETag("\"#{s3_object.md5}\"")
          contents.Size(s3_object.size)
          contents.StorageClass("STANDARD")

          contents.Owner { |owner|
            owner.ID("abc")
            owner.DisplayName("You")
          }
        }
      end
    end

    def self.append_common_prefixes_to_list_bucket_result(lbr, prefixes)
      return if prefixes.nil? or prefixes.size == 0

      prefixes.each do |common_prefix|
        lbr.CommonPrefixes { |contents| contents.Prefix(common_prefix) }
      end
    end

    def self.bucket_query(bucket_query)
      output = ""
      bucket = bucket_query.bucket
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.ListBucketResult(:xmlns => "http://s3.amazonaws.com/doc/2006-03-01/") { |lbr|
        lbr.Name(bucket.name)
        lbr.Prefix(bucket_query.prefix)
        lbr.Marker(bucket_query.marker)
        lbr.MaxKeys(bucket_query.max_keys)
        lbr.IsTruncated(bucket_query.is_truncated?)
        append_objects_to_list_bucket_result(lbr,bucket_query.matches)
        append_common_prefixes_to_list_bucket_result(lbr, bucket_query.common_prefixes)
      }
      output
    end

    # ACL xml
    def self.acl(object = nil)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.AccessControlPolicy(:xmlns => "http://s3.amazonaws.com/doc/2006-03-01/") { |acp|
        acp.Owner do |owner|
          owner.ID("abc")
          owner.DisplayName("You")
        end
        acp.AccessControlList do |acl|
          acl.Grant do |grant|
            grant.Grantee("xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xsi:type" => "CanonicalUser") do |grantee|
              grantee.ID("abc")
              grantee.DisplayName("You")
            end
            grant.Permission("FULL_CONTROL")
          end
        end
      }
      output
    end

    # <CopyObjectResult>
    #   <LastModified>2009-10-28T22:32:00</LastModified>
    #   <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
    # </CopyObjectResult>
    def self.copy_object_result(object)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.CopyObjectResult { |result|
        result.LastModified(object.modified_date)
        result.ETag("\"#{object.md5}\"")
      }
      output
    end

    # <CompleteMultipartUploadResult>
    #   <Location>http://Example-Bucket.s3.amazonaws.com/Example-Object</Location>
    #   <Bucket>Example-Bucket</Bucket>
    #   <Key>Example-Object</Key>
    #   <ETag>"3858f62230ac3c915f300c664312c11f-9"</ETag>
    # </CompleteMultipartUploadResult>
    def self.complete_multipart_result(object)
      output = ""
      xml = Builder::XmlMarkup.new(:target => output)
      xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      xml.CompleteMultipartUploadResult { |result|
        result.Location("TODO: implement")
        result.Bucket("TODO: implement")
        result.Key(object.name)
        result.ETag("\"#{object.md5}\"")
      }
      output
    end
  end
end
