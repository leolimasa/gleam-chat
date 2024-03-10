import gleam/erlang/process
import gleam/otp/actor
import app
import server
import client

pub fn main() {
  let assert Ok(app) = app.start(
    fn (subject, msg) { actor.send(subject, client.Send(msg)) }
  )
  server.start(app, 3030)

  process.sleep_forever()
}
