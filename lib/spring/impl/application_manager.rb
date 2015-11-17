require "spring/platform"

if Spring.fork?
  require "spring/impl/fork/application_manager"
else
  require "spring/impl/pool/application_manager"
end
