require "spring/platform"
# This is necessary for the terminal to work correctly when we reopen stdin.
Process.setsid if Spring.fork?

require "spring/application"

app = Spring::Application.new(
  Spring::WorkerChannel.remote_endpoint,
  Spring::JSON.load(ENV.delete("SPRING_ORIGINAL_ENV").dup)
)

Signal.trap("TERM") { app.terminate }

Spring::ProcessTitleUpdater.run { |distance|
  "spring app    | #{app.app_name} | started #{distance} ago | #{app.app_env} mode"
}

app.eager_preload if ENV.delete("SPRING_PRELOAD") == "1"
app.run
