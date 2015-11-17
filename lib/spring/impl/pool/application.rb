module Spring
  module ApplicationImpl
    def send_ready_to_manager
      manager.puts Process.pid
    end

    def receive_streams(client)
      []
    end

    def reopen_streams(streams)
      # NOP
    end

    def eager_preload
      preload
    end

    def before_command
      screen_move_to_bottom
      sleep 0.1 until screen_attached?
    end

    def screen_attached?
      !system(%{screen -ls | grep "#{ENV['SPRING_SCREEN_NAME']}" | grep Detached > /dev/null})
    end

    def screen_move_to_bottom
      puts "\033[22B"
    end

    def fork_child(client, streams, child_started)
      manager.puts ENV["SPRING_SCREEN_NAME"]
      child_started[0] = true
      exitstatus = 0
      begin
        yield
      rescue SystemExit => ex
        exitstatus = ex.status
      end

      log "#{Process.pid} exited with #{exitstatus}"
      exit
    end
  end
end
