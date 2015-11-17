require "spring-jruby/platform"

if Spring.fork?
  require "spring-jruby/impl/fork/application"
else
  require "spring-jruby/impl/pool/application"
end
