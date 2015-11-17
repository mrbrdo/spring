module Spring
  module Client
    module RunImpl
      TIMEOUT = 60

      def queue_signals
        # NOP
      end

      def send_std_io_to(application)
        # NOP
      end

      def run_on(application, screen_name)
        application.close
        server.close

        # Using vt100 because it does not have smcup/rmcup support,
        # which means the output of the screen will stay shown after
        # screen closes.
        set_vt_100 = "export TERM=vt100; tset"
        erase_screen_message = "echo '\\033[2A\\033[K'"
        Kernel.exec("#{set_vt_100}; screen -r #{screen_name}; #{erase_screen_message}")
      end
    end
  end
end
