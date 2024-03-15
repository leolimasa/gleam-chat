import gleam/erlang/process
import gleam/otp/actor
import broadcaster
import server

pub fn main() {
  let assert Ok(br) = broadcaster.start()
  let assert Ok(_) = server.start(
    fn(client) {
      actor.send(br, broadcaster.AddClient(client))
    },
    fn(msg) {
      actor.send(br, broadcaster.Broadcast(process.self(), msg))
    },
    3030)

  process.sleep_forever()
}
