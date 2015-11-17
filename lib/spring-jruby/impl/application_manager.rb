require "spring-jruby/platform"

if Spring.fork?
  require "spring-jruby/impl/fork/application_manager"
else
  require "spring-jruby/impl/pool/application_manager"
end
