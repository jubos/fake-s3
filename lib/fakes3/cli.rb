require 'thor'
require 'fakes3/server'
require 'fakes3/version'

module FakeS3
  class CLI < Thor
    default_task("server")

    desc "server", "Run a server on a particular hostname"
    method_option :root, :type => :string, :aliases => '-r', :required => true
    method_option :port, :type => :numeric, :aliases => '-p', :required => true
    method_option :address, :type => :string, :aliases => '-a', :required => false, :desc => "Bind to this address. Defaults to 0.0.0.0"
    method_option :hostname, :type => :string, :aliases => '-H', :desc => "The root name of the host.  Defaults to s3.amazonaws.com."
    method_option :limit, :aliases => '-l', :type => :string, :desc => 'Rate limit for serving (ie. 50K, 1.0M)'
    method_option :sslcert, :type => :string, :desc => 'Path to SSL certificate'
    method_option :sslkey, :type => :string, :desc => 'Path to SSL certificate key'

    def server
      store = nil
      if options[:root]
        root = File.expand_path(options[:root])
        # TODO Do some sanity checking here
        store = FileStore.new(root)
      end

      if store.nil?
        abort "You must specify a root to use a file store (the current default)"
      end

      # Allow single or multiple hostnames
      raw_hostnames = options[:hostname] || 's3.amazonaws.com'
      raw_hostnames = raw_hostnames.split(/[\s,]/)
      hostnames = []
      raw_hostnames.each do |h|
        # In case the user has put a port on the hostname
        if h =~ /:(\d+)/
          h = h.split(":")[0]
        end
        h.strip!
        if not (/\A[[:space:]]*\z/ === h)
          hostnames << h
        end
      end
      hostnames.uniq!

      if options[:limit]
        begin
          store.rate_limit = options[:limit]
        rescue
          abort $!.message
        end
      end

      address = options[:address] || '0.0.0.0'
      ssl_cert_path = options[:sslcert]
      ssl_key_path = options[:sslkey]

      if (ssl_cert_path.nil? && !ssl_key_path.nil?) || (!ssl_cert_path.nil? && ssl_key_path.nil?)
        abort "If you specify an SSL certificate you must also specify an SSL certificate key"
      end

      puts "Loading FakeS3 with #{root} on port #{options[:port]} with hostnames #{hostnames}"
      server = FakeS3::Server.new(address,options[:port],store,hostnames,ssl_cert_path,ssl_key_path)
      server.serve
    end

    desc "version", "Report the current fakes3 version"
    def version
      puts <<"EOF"
======================
FakeS3 #{FakeS3::VERSION}

Copyright 2012, Curtis Spencer (@jubos)
EOF
    end
  end
end
