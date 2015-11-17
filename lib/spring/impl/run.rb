require "spring/platform"

if Spring.fork?
  require "spring/impl/fork/run"
else
  require "spring/impl/pool/run"
end
