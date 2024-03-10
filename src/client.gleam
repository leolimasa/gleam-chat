import gleam/erlang/process.{type Subject}
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
  Send(msg: String) 
  Receive(msg: String)
}

fn handle_message(msg: Msg, state: State) {
  case msg {
    Send(m) -> {
      case tcp.send(state.socket, bytes_builder.from_string(m)) {
        Error(_e) -> {
          io.println("could not send message via socket")
          actor.continue(state)
        }
        Ok(_ok) -> actor.continue(state)
      }
    }
    Receive(m) -> {
      actor.send(state.app, app.Broadcast(m))
      actor.continue(state)
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
