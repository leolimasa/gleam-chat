import glisten.{User, Packet}
import gleam/bit_array
import gleam/otp/actor.{InitFailed}
import gleam/erlang/process.{type Subject, type Pid, Abnormal}
import gleam/io
import gleam/option.{Some}
import gleam/function
import gleam/bytes_builder
import gleam/string
import gleam/result

pub type ClientMsg {
  Send(msg: String)
}

pub fn start(
  on_new_client: fn(Subject(ClientMsg)) -> Nil,
  on_message: fn(String) -> Nil,
  port: Int,
) {
  glisten.handler(
    fn() {
      let subj = process.new_subject()
      on_new_client(subj)
      #(Nil, Some(process.new_selector() |> process.selecting(subj, function.identity))) 
    },
    fn(msg, state, conn) {
      case msg {
        Packet(p) -> {
          case bit_array.to_string(p) {
            Ok(p_str) -> on_message(p_str)
            Error(e) -> {
              io.println("could not decode packet")
              io.debug(e)
            }
          }
          actor.continue(state)
        }
        User(Send(m)) -> {
          case glisten.send(conn, bytes_builder.from_string(m)) {
            Ok(_) -> {
              actor.continue(state)
            }
            Error(e) -> {
              io.println("could not send message")
              io.debug(e)
              actor.continue(state)
            }
          }
        }
      }
    })
    |> glisten.serve(port)
    |> result.map_error(fn (e) {
       InitFailed(Abnormal(string.inspect(e)))
    })
}
