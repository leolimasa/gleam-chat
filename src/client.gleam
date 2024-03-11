import gleam/erlang/process.{type Pid, type Subject}
import gleam/otp/actor.{type StartError}
import gleam/result
import gleam/bytes_builder
import gleam/io
import glisten/socket.{type Socket}
import glisten/tcp
import app

pub type State {
  State(app: Subject(app.Msg(Msg)), socket: Socket)
}

pub type Msg {
  Send(pid: Pid, msg: String)
  Receive(msg: String)
  Shutdown
}

fn handle_message(msg: Msg, state: State) {
  case msg {
    Send(pid, m) -> {
      case pid == process.self() {
        True -> actor.continue(state)
        False ->
          case tcp.send(state.socket, bytes_builder.from_string(m)) {
            Error(_e) -> {
              io.println("could not send message via socket")
              actor.continue(state)
            }
            Ok(_ok) -> actor.continue(state)
          }
      }
    }
    Receive(m) -> {
      actor.send(state.app, app.Broadcast(process.self(), m))
      actor.continue(state)
    }
    Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}

pub fn start(
  app: Subject(app.Msg(Msg)),
  socket: Socket,
) -> Result(Subject(Msg), StartError) {
  use self <- result.map(actor.start(
    State(app: app, socket: socket),
    handle_message,
  ))
  actor.send(app, app.AddClient(self))
  self
}
