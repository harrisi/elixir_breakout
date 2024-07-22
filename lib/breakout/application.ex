defmodule Breakout.Application do
  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      # having ResourceManager as a separate app makes things difficult because
      # that means I need to share the context. I should probably see what it
      # would look like to move all opengl stuff to it's own application
      # (Renderer), but I just realized that gets kinda complicated - what about
      # the window? should the renderer also handle input? hm.

      # for now, I'm actually going to just have a single app. it makes handling
      # opengl stuff easier.

      # Breakout.ResourceManager,
      Breakout.Game
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Breakout.Supervisor, auto_shutdown: :any_significant]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    IO.inspect("in application stop")

    :init.stop()
  end
end
