import glisten.{type SocketReason}
import glisten/tcp
import glisten/socket/options.{ActiveMode, Passive}
import gleam/bit_array
import gleam/otp/actor.{type StartError}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/result.{map_error}
import client
import app

fn receive_loop(client, socket) {
  use message <- result.then(tcp.receive(socket, 0))
  case bit_array.to_string(message) {
    Ok(s) -> actor.send(client, client.Receive(s))
    Error(_e) -> io.println("Could not decode message")
  }
  receive_loop(client, socket)
}

type LoopError {
  LoopSocketReason(SocketReason)
  LoopStartError(StartError)
}

fn accept_loop(app: Subject(app.Msg(client.Msg)), listener) -> Result(Nil, LoopError) {
  // Accept the new connection
  use socket <- result.then(
    tcp.accept(listener)
    |> map_error(LoopSocketReason),
  )

  // Start a new client
  use client <- result.then(
    client.start(app, socket)
    |> map_error(LoopStartError),
  )

  // Start a receiver process that sends a message to the client every time 
  // a message is received.
  process.start(
    fn() {
      // Link the receiver process with the client so that if this process quits,
      // the client also quits and vice versa.
      process.link(process.subject_owner(client))

      // Receive messages from the socket and send them to the client actor.
      receive_loop(client, socket)
    },
    linked: False,
  )

  // Receive another message
  accept_loop(app, listener)
}

pub fn start(app: Subject(app.Msg(client.Msg)), port: Int) {
  process.start(
    fn() {
      use listener <- result.map(tcp.listen(port, [ActiveMode(Passive)]))
      accept_loop(app, listener)
    },
    linked: False,
  )
}
