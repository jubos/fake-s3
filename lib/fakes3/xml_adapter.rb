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

    # <?xml version="1.0" encoding="UTF-8"?>
    #<Error>
    #  <Code>NoSuchKey</Code>
    #  <Message>The resource you requested does not exist</Message>
    #  <Resource>/mybucket/myfoto.jpg</Resource> 
    #  <RequestId>4442587FB7D0A2F9</RequestId>
    #</Error> 
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
  end
end
