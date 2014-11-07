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
    method_option :hostname, :type => :string, :aliases => '-h', :desc => "The root name of the host.  Defaults to s3.amazonaws.com."
    method_option :limit, :aliases => '-l', :type => :string, :desc => 'Rate limit for serving (ie. 50K, 1.0M)'
    method_option :ssl, :aliases => '-s', :type => :boolean, :desc => 'Should SSL be used or not.'
    method_option :key, :aliases => '-k', :type => :string, :desc => 'The Key for SSL encryption.'
    method_option :cert, :aliases => '-c', :type => :string, :desc => 'The Certificate for SSL encryption.'

    def server
      store = nil
      if options[:root]
        root = File.expand_path(options[:root])
        # TODO Do some sanity checking here
        store = FileStore.new(root)
      end

      if store.nil?
        puts "You must specify a root to use a file store (the current default)"
        exit(-1)
      end

      hostname = 's3.amazonaws.com'
      if options[:hostname]
        hostname = options[:hostname]
        # In case the user has put a port on the hostname
        if hostname =~ /:(\d+)/
          hostname = hostname.split(":")[0]
        end
      end

      if options[:limit]
        begin
          store.rate_limit = options[:limit]
        rescue
          puts $!.message
          exit(-1)
        end
      end

      enable_ssl = nil
      if options[:ssl]
        begin
          enable_ssl = options[:ssl]
        rescue
          puts $!.message
          exit(-1)
        end  
      end

      key = nil
      if options[:key]
        begin
          key = options[:key]
        rescue
          puts $!.message
          exit(-1)
        end  
      end

      cert = nil
      if options[:cert]
        begin
          cert = options[:cert]
        rescue
          puts $!.message
          exit(-1)
        end  
      end

      if enable_ssl and (!key or !cert)
        puts "If you want to use SSL, please provide both a key (-k) and a certificate (-c)."
        exit(-1)
      end

      puts "Loading FakeS3 with #{root} on port #{options[:port]} with hostname #{hostname}"
      if enable_ssl
        puts "using the certificate #{cert} and key #{key} for SSL."
      end
      address = options[:address] || '0.0.0.0'

      puts "Loading FakeS3 with #{root} on port #{options[:port]} with hostname #{hostname}"
      server = FakeS3::Server.new(address,options[:port],store,hostname,enable_ssl,key,cert)
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
