require "rbconfig"
require "socket"
require "bundler"
require "spring-jruby/io_helpers"
require "spring-jruby/impl/run"

module Spring
  module Client
    class Run < Command
      include RunImpl
      TIMEOUT = RunImpl::TIMEOUT

      def initialize(args)
        super
        @signal_queue = []
      end

      def log(message)
        env.log "[client] #{message}"
      end

      def server
        @server ||= UNIXSocket.open(env.socket_name)
      end

      def call
        if env.server_running?
          warm_run
        else
          cold_run
        end
      rescue Errno::ECONNRESET
        exit 1
      ensure
        server.close if @server
      end

      def warm_run
        run
      rescue CommandNotFound
        require "spring-jruby/commands"

        if Spring.command?(args.first)
          # Command installed since spring started
          stop_server
          cold_run
        else
          raise
        end
      end

      def cold_run
        boot_server
        run
      end

      def run
        verify_server_version

        application, client = WorkerChannel.pair

        queue_signals
        connect_to_application(client)
        run_command(client, application.to_io)
      end

      def boot_server
        env.socket_path.unlink if env.socket_path.exist?

        pid = Process.spawn(
          gem_env,
          "ruby",
          "-e", "gem 'spring-jruby', '#{Spring::VERSION}'; require 'spring-jruby/server'; Spring::Server.boot"
        )

        until env.socket_path.exist?
          _, status = Process.waitpid2(pid, Process::WNOHANG)
          exit status.exitstatus if status
          sleep 0.1
        end
      end

      def gem_env
        bundle = Bundler.bundle_path.to_s
        paths  = Gem.path + ENV["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)

        {
          "GEM_PATH" => [bundle, *paths].uniq.join(File::PATH_SEPARATOR),
          "GEM_HOME" => bundle
        }
      end

      def stop_server
        server.close
        @server = nil
        env.stop
      end

      def verify_server_version
        server_version = server.gets.chomp
        if server_version != env.version
          $stderr.puts <<-ERROR
There is a version mismatch between the spring client and the server.
You should restart the server and make sure to use the same version.

CLIENT: #{env.version}, SERVER: #{server_version}
ERROR
          exit 1
        end
      end

      def connect_to_application(client)
        client.forward_to(server)
        send_json server, "args" => args, "default_rails_env" => default_rails_env

        if IO.select([server], [], [], TIMEOUT)
          server.gets or raise CommandNotFound
        else
          raise "Error connecting to Spring server"
        end
      end

      def run_command(client, application)
        log "sending command"

        send_std_io_to(application)

        send_json application, "args" => args, "env" => ENV.to_hash

        IO.select([server])
        pid = server.gets
        pid = pid.chomp if pid

        # We must not close the client socket until we are sure that the application has
        # received the FD. Otherwise the FD can end up getting closed while it's in the server
        # socket buffer on OS X. This doesn't happen on Linux.
        client.close

        if pid && !pid.empty?
          log "got pid: #{pid}"

          run_on(application, pid)
        else
          log "got no pid"
          exit 1
        end
      ensure
        application.close
      end

      def kill(sig, pid)
        Process.kill(sig, -Process.getpgid(pid))
      end

      def send_json(socket, data)
        data = JSON.dump(data)

        socket.puts  data.bytesize
        socket.write data
      end

      def default_rails_env
        ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end
    end
  end
end
