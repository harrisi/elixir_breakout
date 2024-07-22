defmodule Breakout.Renderer do
  require Logger

  alias Breakout.Math.Vec3
  alias Breakout.Math.Vec2
  # alias Breakout.ResourceManager
  alias Breakout.Renderer.Sprite
  @spec draw(state :: Breakout.State.t()) :: :ok
  def draw(state) do
    IO.inspect("is this called")
    case state.resources.textures[:face] do
      {:ok, texture} ->
        t = :erlang.monotonic_time(:millisecond)

        Sprite.draw(
          state.sprite_renderer,
          texture,
          Vec2.new(:math.cos(t / 1000) * 550 + 550, :math.sin(t / 1000) * 325 + 325),
          Vec2.new(100, 100),
          :math.sin(t / 1000) * :math.pi(),
          Vec3.new(0, 1, 0)
        )

      nil ->
        nil
    end

    :ok
  end
end
