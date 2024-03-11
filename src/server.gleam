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

type AcceptLoopError {
  LoopSocketReason(SocketReason)
  LoopStartError(StartError)
}

fn accept_loop(app: Subject(app.Msg(client.Msg)), listener) -> Result(Nil, AcceptLoopError) {
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

  // Start a receiver process that waits until a message arrives in the socket
  // and then forwards it to the client.
  process.start(
    fn() {
      // Receive messages from the socket and send them to the client actor.
      receive_loop(client, socket)

      // Shutdown the client once the connection closes
      io.println("Client quit")
      actor.send(client, client.Shutdown)
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
