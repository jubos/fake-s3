require 'thor'
require 'fakes3/server'
require 'fakes3/version'

module FakeS3
  class CLI < Thor
    default_task("server")

    desc "server", "Run a server on a particular hostname"
    method_option :root, :type => :string, :aliases => '-r', :required => true
    method_option :port, :type => :numeric, :aliases => '-p', :required => true
    method_option :address, :type => :string, :aliases => '-a', :required => false, :desc => "Bind to this address. Defaults to all IP addresses of the machine."
    method_option :hostname, :type => :string, :aliases => '-H', :desc => "The root name of the host.  Defaults to s3.amazonaws.com."
    method_option :quiet, :type => :boolean, :aliases => '-q', :desc => "Quiet; do not write anything to standard output."
    method_option :limit, :aliases => '-l', :type => :string, :desc => 'Rate limit for serving (ie. 50K, 1.0M)'
    method_option :sslcert, :type => :string, :desc => 'Path to SSL certificate'
    method_option :sslkey, :type => :string, :desc => 'Path to SSL certificate key'
    method_option :corsorigin, :type => :string, :desc => 'Access-Control-Allow-Origin header return value'
    method_option :corsmethods, :type => :string, :desc => 'Access-Control-Allow-Methods header return value'
    method_option :corspreflightallowheaders, :type => :string, :desc => 'Access-Control-Allow-Headers header return value for preflight OPTIONS requests'
    method_option :corspostputallowheaders, :type => :string, :desc => 'Access-Control-Allow-Headers header return value for POST and PUT requests'
    method_option :corsexposeheaders, :type => :string, :desc => 'Access-Control-Expose-Headers header return value'

    def server
      store = nil
      if options[:root]
        root = File.expand_path(options[:root])
        # TODO Do some sanity checking here
        store = FileStore.new(root, !!options[:quiet])
      end

      if store.nil?
        abort "You must specify a root to use a file store (the current default)"
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
          abort $!.message
        end
      end

      cors_options = {}
      cors_options['allow_origin'] = options[:corsorigin] if options[:corsorigin]
      cors_options['allow_methods'] = options[:corsmethods] if options[:corsmethods]
      cors_options['preflight_allow_headers'] = options[:corspreflightallowheaders] if options[:corspreflightallowheaders]
      cors_options['post_put_allow_headers'] = options[:corspostputallowheaders] if options[:corspostputallowheaders]
      cors_options['expose_headers'] = options[:corsexposeheaders] if options[:corsexposeheaders]

      address = options[:address]
      ssl_cert_path = options[:sslcert]
      ssl_key_path = options[:sslkey]

      if (ssl_cert_path.nil? && !ssl_key_path.nil?) || (!ssl_cert_path.nil? && ssl_key_path.nil?)
        abort "If you specify an SSL certificate you must also specify an SSL certificate key"
      end

      puts "Loading FakeS3 with #{root} on port #{options[:port]} with hostname #{hostname}" unless options[:quiet]
      server = FakeS3::Server.new(address,options[:port],store,hostname,ssl_cert_path,ssl_key_path, quiet: !!options[:quiet], cors_options: cors_options)
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
