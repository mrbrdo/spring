require "spring-jruby/platform"

if Spring.fork?
  require "spring-jruby/impl/fork/run"
else
  require "spring-jruby/impl/pool/run"
end
