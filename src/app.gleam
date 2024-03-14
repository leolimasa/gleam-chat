import gleam/io
import gleam/otp/actor.{type StartError, Spec}
import gleam/erlang/process.{
  type Pid, type ProcessDown, type ProcessMonitor, type Selector, type Subject,
}
import gleam/dict.{type Dict}
import gleam/result.{try}
import server

type Client {
  Client(subject: Subject(server.ClientMsg), monitor: ProcessMonitor)
}

pub type Msg {
  Broadcast(origin: Pid, msg: String)
  AddClient(client: Subject(server.ClientMsg))
  RemoveClient(pid: Pid)
}

type State {
  State(clients: Dict(Pid, Client), selector: Selector(Msg))
}

// Selectors are needed to listen to more than one subject. In this case,
// we listen to ProcessDown messages that are created by a monitor. 
// The ProcessDown messages are converted to RemoveClient messages that
// are processed by the actor.
fn build_selector(clients: Dict(Pid, Client)) {
  dict.fold(clients, process.new_selector(), fn(selector, pid, client) {
    // The selecting_process_down function adds a selector to an existing selector
    process.selecting_process_down(
      selector,
      client.monitor,
      fn(_process: ProcessDown) { RemoveClient(pid) },
    )
  })
}

fn handle_message(msg: Msg, state: State) -> actor.Next(Msg, State) {
  case msg {
    Broadcast(pid, m) -> {
      // Only broadcast to subjects that are not the origin PID
      dict.filter(state.clients, fn(c_pid, _c) { pid != c_pid })
      |> dict.map_values(fn(_pid, c) { actor.send(c.subject, server.Send(m)) })
      actor.continue(state)
    }

    AddClient(c) -> {
      io.println("Adding new client")
      let pid = process.subject_owner(c)
      let monitor = process.monitor_process(pid)
      let client = Client(subject: c, monitor: monitor)
      let new_state =
        State(..state, clients: dict.insert(state.clients, pid, client))
      actor.continue(new_state)
      |> actor.with_selector(build_selector(new_state.clients))
    }

    RemoveClient(c) -> {
      io.println("Removing client")
      let new_state = State(..state, clients: dict.delete(state.clients, c))
      actor.continue(new_state)
      |> actor.with_selector(build_selector(new_state.clients))
    }
  }
}

fn handle_init() {
  let selector = process.new_selector()
  let state = State(clients: dict.new(), selector: selector)
  actor.Ready(state, selector)
}

pub fn start() -> Result(Subject(Msg), StartError) {
  actor.start_spec(Spec(
    init: fn() { handle_init() },
    init_timeout: 10,
    loop: handle_message,
  ))
}
