module Spring
  module ApplicationImpl
    def send_ready_to_manager
      manager.puts
    end

    def receive_streams(client)
      3.times.map { IOWrapper.recv_io(client).to_io }
    end

    def reopen_streams(streams)
      [STDOUT, STDERR, STDIN].zip(streams).each { |a, b| a.reopen(b) }
    end

    def eager_preload
      with_pty { preload }
    end

    def with_pty
      PTY.open do |master, slave|
        [STDOUT, STDERR, STDIN].each { |s| s.reopen slave }
        Thread.new { master.read }
        yield
        reset_streams
      end
    end

    def reset_streams
      [STDOUT, STDERR].each { |stream| stream.reopen(spring_env.log_file) }
      STDIN.reopen("/dev/null")
    end

    def before_command
      # NOP
    end

    def fork_child(client, streams, child_started)
      pid = fork { yield }
      child_started[0] = true

      disconnect_database
      reset_streams

      log "forked #{pid}"
      manager.puts pid

      wait pid, streams, client
    end
  end
end
