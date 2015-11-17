module Spring
  class ApplicationManager
    class Worker
      attr_reader :screen_pid, :pid, :uuid, :socket, :screen_name
      attr_accessor :on_done

      def initialize(env, args)
        @spring_env = Env.new
        channel, @remote_socket = WorkerChannel.pair
        @uuid = File.basename(@remote_socket.path).gsub('.sock', '')

        Bundler.with_clean_env do
          spawn_screen(
            env.merge("SPRING_SOCKET" => @remote_socket.path),
            args
          )
        end

        @socket = channel.to_io
      end

      def spawn_screen(env, args)
        @screen_name = "spring_#{@uuid}"

        @screen_pid =
          Process.spawn(
            env.merge("SPRING_SCREEN_NAME" => screen_name),
            "screen", "-d", "-m", "-S", screen_name,
            *args
          )

        log "(spawn #{@screen_pid})"
      end

      def await_boot
        Process.detach(screen_pid)
        @pid = socket.gets.to_i
        start_wait_thread(pid, socket) unless pid.zero?
        @remote_socket.close
      end

      def start_wait_thread(pid, child)
        Thread.new {
          begin
            Process.kill(0, pid) while sleep(1)
          rescue Errno::ESRCH
          end

          log "child #{pid} shutdown"

          on_done.call(self) if on_done
        }
      end

      def log(message)
        @spring_env.log "[worker:#{uuid}] #{message}"
      end
    end

    class WorkerPool
      def initialize(app_env, *app_args)
        @app_env = app_env
        @app_args = app_args
        @spring_env = Env.new

        @workers = []
        @workers_in_use = []
        @spawning_workers = []

        @check_mutex = Mutex.new
        @workers_mutex = Mutex.new

        run
      end

      def add_worker
        worker = Worker.new(@app_env, @app_args)
        worker.on_done = method(:worker_done)
        @workers_mutex.synchronize { @spawning_workers << worker }
        Thread.new do
          worker.await_boot
          log "+ worker #{worker.pid} (#{worker.uuid})"
          @workers_mutex.synchronize do
            @spawning_workers.delete(worker)
            @workers << worker
          end
        end
      end

      def worker_done(worker)
        log "- worker #{worker.pid} (#{worker.uuid})"
        @workers_mutex.synchronize do
          @workers_in_use.delete(worker)
        end
      end

      def get_worker(spawn_new = true)
        add_worker if spawn_new && all_size == 0

        worker = nil
        while worker.nil? && all_size > 0
          @workers_mutex.synchronize do
            worker = @workers.shift
            @workers_in_use << worker if worker
          end
          break if worker
          sleep 1
        end

        Thread.new { check_min_free_workers } if spawn_new

        worker
      end

      def check_min_free_workers
        if @check_mutex.try_lock
          # TODO: mutex, and dont do it if already in progress
          # do this in thread
          while all_size < Spring.pool_min_free_workers
            unless Spring.pool_spawn_parallel
              sleep 0.1 until @workers_mutex.synchronize { @spawning_workers.empty? }
            end
            add_worker
          end
          @check_mutex.unlock
        end
      end

      def all_size
        @workers_mutex.synchronize { @workers.size + @spawning_workers.size }
      end

      def stop!
        if spawning_worker_pids.include?(nil)
          log "Waiting for workers to quit..."
          sleep 0.1 while spawning_worker_pids.include?(nil)
        end

        @workers_mutex.synchronize do
          (@spawning_workers + @workers_in_use + @workers).each do |worker|
            kill_worker(worker)
          end
        end
      end
    private
      def kill_worker(worker)
        log "- worker #{worker.pid} (#{worker.uuid})."
        system("kill -9 #{worker.pid} > /dev/null 2>&1")
        system("screen -S #{worker.screen_name} -X quit > /dev/null 2>&1")
      rescue
      end

      def spawning_worker_pids
        @spawning_workers.map { |worker| worker.pid }
      end

      def run
        system("screen -wipe > /dev/null 2>&1")

        check_min_free_workers
      end

      def log(message)
        @spring_env.log "[worker:pool] #{message}"
      end
    end

    def initialize(app_env)
      @app_env    = app_env
      @spring_env = Env.new
      @pool       =
        WorkerPool.new(
          {
            "RAILS_ENV"           => app_env,
            "RACK_ENV"            => app_env,
            "SPRING_ORIGINAL_ENV" => JSON.dump(Spring::ORIGINAL_ENV),
            "SPRING_PRELOAD"      => "1",
          },
          Spring.ruby_bin,
          "-I", File.expand_path("../..", __FILE__),
          "-e", "require 'spring-jruby/application/boot'"
        )
    end

    # Returns the name of the screen running the command, or nil if the application process died.
    def run(client)
      name = nil
      with_child do |child|
        client.forward_to(child.socket)
        child.socket.gets or raise Errno::EPIPE

        name = child.socket.gets
      end

      unless name.nil?
        log "got worker name #{name}"
        name
      end
    rescue Errno::ECONNRESET, Errno::EPIPE => e
      log "#{e} while reading from child; returning no name"
      nil
    ensure
      client.close
    end

    def stop
      log "stopping"

      @pool.stop!
    rescue Errno::ESRCH, Errno::ECHILD
      # Don't care
    end

    protected

    attr_reader :app_env, :spring_env

    def log(message)
      spring_env.log "[application_manager:#{app_env}] #{message}"
    end

    def with_child
      yield(@pool.get_worker)
    end
  end
end
