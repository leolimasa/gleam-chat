import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervisor.{add, worker}
import app
import server

pub fn main() {
  let assert Ok(app) = app.start()
  server.start(
    fn(client) {
      actor.send(app, app.AddClient(client))
    },
    fn(msg) {
      actor.send(app, app.Broadcast(process.self(), msg))
    },
    3030)

  process.sleep_forever()
}
