require_relative "../helper"
require "spring-jruby/test/watcher_test"
require "spring-jruby/watcher/polling"

class PollingWatcherTest < Spring::Test::WatcherTest
  def watcher_class
    Spring::Watcher::Polling
  end
end
