# Breakout

Breakout in Elixir using OpenGL. Largely an incomplete and poor port of
https://learnopengl.com/In-Practice/2D-Game/Breakout.

## Pre-emptive notes

The code is very bad. I'm working on improving it. Please feel free to suggest
updates/changes, ideally with an eye towards how games can be implemented in the
future (i.e., not just improvements to this breakout implementation, but game
development in Elixir as a whole).

## Launching

This implementation has no dependencies. The following should work (tested on
modern macOS, Ubuntu, and Windows):

```sh
$ git clone https://github.com/harrisi/elixir_breakout
$ iex -S mix # or mix run --no-halt
```

## Gameplay

`A`/`D`, `H`/`L` (hello, fellow vim users), or left/right arrows to move
left/right, space to launch the ball, `N` to switch between levels, `P` to
profile with tprof for ten seconds (if you're in to that).

There is no win condition.