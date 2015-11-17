require "spring-jruby/errors"
require "spring-jruby/json"

require "spring-jruby/client/command"
require "spring-jruby/client/run"
require "spring-jruby/client/help"
require "spring-jruby/client/binstub"
require "spring-jruby/client/stop"
require "spring-jruby/client/status"
require "spring-jruby/client/rails"
require "spring-jruby/client/version"

module Spring
  module Client
    COMMANDS = {
      "help"      => Client::Help,
      "-h"        => Client::Help,
      "--help"    => Client::Help,
      "binstub"   => Client::Binstub,
      "stop"      => Client::Stop,
      "status"    => Client::Status,
      "rails"     => Client::Rails,
      "-v"        => Client::Version,
      "--version" => Client::Version,
    }

    def self.run(args)
      command_for(args.first).call(args)
    rescue CommandNotFound
      Client::Help.call(args)
    rescue ClientError => e
      $stderr.puts e.message
      exit 1
    end

    def self.command_for(name)
      COMMANDS[name] || Client::Run
    end
  end
end

# allow users to add hooks that do not run in the server
# or modify start/stop
if File.exist?("config/spring_client.rb")
  require "./config/spring_client.rb"
end
