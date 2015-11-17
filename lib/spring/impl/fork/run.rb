module Spring
  module Client
    module RunImpl
      TIMEOUT = 1
      FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO) & Signal.list.keys

      def queue_signals
        RunImpl::FORWARDED_SIGNALS.each do |sig|
          trap(sig) { @signal_queue << sig }
        end
      end

      def send_std_io_to(application)
        application.send_io STDOUT
        application.send_io STDERR
        application.send_io STDIN
      end

      def run_on(application, pid)
        forward_signals(pid.to_i)
        status = application.read.to_i

        log "got exit status #{status}"

        exit status
      end

      def forward_signals(pid)
        @signal_queue.each { |sig| kill sig, pid }

        RunImpl::FORWARDED_SIGNALS.each do |sig|
          trap(sig) { forward_signal sig, pid }
        end
      rescue Errno::ESRCH
      end

      def forward_signal(sig, pid)
        kill(sig, pid)
      rescue Errno::ESRCH
        # If the application process is gone, then don't block the
        # signal on this process.
        trap(sig, 'DEFAULT')
        Process.kill(sig, Process.pid)
      end
    end
  end
end
