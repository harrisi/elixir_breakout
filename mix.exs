defmodule Breakout.MixProject do
  use Mix.Project

  def project do
    [
      app: :breakout,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx, :observer, :runtime_tools, :tools, :xmerl, :debugger],
      mod: {Breakout.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 1.1"},
      {:membrane_file_plugin, "~> 0.17.2"},
      {:membrane_portaudio_plugin, "~> 0.19.2"},
      {:membrane_ffmpeg_swresample_plugin, "~> 0.20.2"},
      {:membrane_mp3_mad_plugin, "~> 0.18.3"},
      # {:exsync, "~> 0.4", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
