require "active_support"
require "active_support/test_case"

ActiveSupport.test_order = :random

module Spring
  module Test
    class << self
      attr_accessor :root
    end

    require "spring-jruby/test/application"
    require "spring-jruby/test/application_generator"
    require "spring-jruby/test/rails_version"
    require "spring-jruby/test/watcher_test"
    require "spring-jruby/test/acceptance_test"
  end
end
