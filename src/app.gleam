import gleam/io
import gleam/otp/actor.{type StartError, Spec}
import gleam/erlang/process.{
  type Pid, type ProcessDown, type ProcessMonitor, type Selector, type Subject,
}
import gleam/dict.{type Dict}

type Client(a) {
  Client(pid: Pid, subject: Subject(a), monitor: ProcessMonitor)
}

pub type Msg(a) {
  Broadcast(msg: String)
  AddClient(client: Subject(a))
  RemoveClient(pid: Pid)
}

type State(a) {
  State(clients: Dict(Pid, Client(a)), selector: Selector(Msg(a)), send_to_client: fn(Subject(a), String) -> Nil)
}

// Selectors are needed to listen to more than one subject. In this case,
// we listen to ProcessDown messages that are created by a monitor. 
// The ProcessDown messages are converted to RemoveClient messages that
// are processed by the actor.
fn build_selector(clients: Dict(Pid, Client(a))) {
  dict.fold(clients, process.new_selector(), fn(selector, _key, client) {
    // The selecting_process_down function adds a selector to an existing selector
    process.selecting_process_down(
      selector,
      client.monitor,
      fn(_process: ProcessDown) { RemoveClient(client.pid) },
    )
  })
}

fn handle_message(msg: Msg(a), state: State(a)) -> actor.Next(Msg(a), State(a)) {
  case msg {
    Broadcast(m) -> {
      dict.map_values(state.clients, fn(_pid, c) {
        state.send_to_client(c.subject, m)
      })
      actor.continue(state)
    }

    AddClient(c) -> {
      io.println("Adding new client")
      let pid = process.subject_owner(c)
      let monitor = process.monitor_process(pid)
      let client = Client(pid: pid, subject: c, monitor: monitor)
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

fn handle_init(send_msg: fn(Subject(a), String) -> Nil) {
  let selector = process.new_selector()
  let state = State(clients: dict.new(), selector: selector, send_to_client: send_msg)
  actor.Ready(state, selector)
}

pub fn start(send_to_client: fn(Subject(a), String) -> Nil) -> Result(Subject(Msg(a)), StartError) {
  actor.start_spec(Spec(
    init: fn() { handle_init(send_to_client) },
    init_timeout: 10,
    loop: handle_message,
  ))
}
