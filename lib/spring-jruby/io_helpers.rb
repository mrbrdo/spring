require "spring-jruby/platform"
require 'socket'
require 'securerandom'

module Spring
  if Spring.fork?
    class IOWrapper
      def self.recv_io(socket, *args)
        new(socket.recv_io(*args))
      end

      def initialize(socket)
        @socket = socket
      end

      def forward_to(socket)
        socket.send_io(@socket)
      end

      def to_io
        @socket
      end

      def close
        @socket.close
      end
    end

    class WorkerChannel
      def self.pair
        a, b = UNIXSocket.pair
        [new(a), IOWrapper.new(b)]
      end

      def self.remote_endpoint
        UNIXSocket.for_fd(3)
      end

      attr_reader :to_io

      def initialize(socket)
        @to_io = socket
      end
    end
  else
    class IOWrapper
      def self.recv_io(socket, *args)
        new(socket.gets.chomp)
      end

      def initialize(path)
        @path = path
      end

      def forward_to(socket)
        socket.puts(@path)
      end

      def to_io
        UNIXSocket.open(@path)
      end

      def path
        @path
      end

      def close
        # nop
      end
    end

    class WorkerChannel
      def self.pair
        path = Env.new.tmp_path.join("#{SecureRandom.uuid}.sock").to_s
        [new(path), IOWrapper.new(path)]
      end

      def self.remote_endpoint
        path = ENV.delete("SPRING_SOCKET")
        UNIXSocket.open(path)
      end

      def initialize(path)
        @server = UNIXServer.open(path)
      end

      def to_io
        @socket ||= @server.accept
      end
    end
  end
end
