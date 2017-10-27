require 'xmlsimple'

module FakeS3
  class XmlParser
    def self.delete_objects(request)
      keys = []

      objects = XmlSimple.xml_in(request.body, {'NoAttr' => true})['Object']
      objects.each do |key|
        keys << key['Key'][0]
      end

      keys
    end
  end
end