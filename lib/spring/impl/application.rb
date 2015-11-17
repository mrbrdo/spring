require "spring/platform"

if Spring.fork?
  require "spring/impl/fork/application"
else
  require "spring/impl/pool/application"
end
