require "bundler/setup"
require "minitest/autorun"

require "spring-jruby/test"
Spring::Test.root = File.expand_path('..', __FILE__)
