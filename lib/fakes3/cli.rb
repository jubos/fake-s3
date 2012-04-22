require 'thor'
require 'fakes3/server'
require 'fakes3/version'

module FakeS3
  class CLI < Thor
    default_task("server")

    desc "server", "Run a server on a particular hostname"
    method_option :root, :type => :string, :aliases => '-r', :required => true
    method_option :port, :type => :numeric, :aliases => '-p', :required => true
    method_option :hostname, :type => :string, :aliases => '-h', :desc => "The root name of the host.  Defaults to 0.0.0.0"
    method_option :limit, :aliases => '-l', :type => :string, :desc => 'Rate limit for serving (ie. 50K, 1.0M)'
    def server
      root = nil
      if options[:root].nil?
        puts "You must specify a root to use a file store (the current default)"
        exit(-1)
      else
        root = File.expand_path(options[:root])
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

      puts "Loading FakeS3 with #{root} on port #{options[:port]} with hostname #{hostname}"
      server = FakeS3::Server.new(options[:port],root,hostname)
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
