# chat

A simple TCP chat demo to demonstrate gleam concurrency patterns.


Here is a list of the major concurrency concepts. For a deeper explanation, see https://github.com/bcpeinhardt/learn_otp_with_gleam

## Processes

TODO

## Subjects

TODO

## Tasks

## Actors

* You can change what the actor listens to ON THE FLY by changing it's selector to include more (or less) subjects
* Do that with process.new_selector() 

## Selectors

Selectors allow listening on more than one `Subject`.
If you create a new `Subject`, you can pass it to the selector of an actor so that it can be listened to.
Selectors have only one message type, so you'll need to map it appropriately.

## Monitors

Monitors when 

## Links

## Supervisors

