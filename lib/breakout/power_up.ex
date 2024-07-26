defmodule Breakout.PowerUp do
  alias Breakout.Renderer.Texture2D
  alias Breakout.Math.Vec2
  alias Breakout.Math.Vec3
  alias Breakout.GameObject

  @type power_up_types ::
          nil | :chaos | :confuse | :increase | :passthrough | :speed | :sticky

  @type t :: %__MODULE__{
          type: power_up_types(),
          duration: float(),
          activated: boolean(),
          game_object: GameObject.t()
        }

  @enforce_keys [:game_object]
  defstruct type: nil,
            duration: 0.0,
            activated: false,
            game_object: GameObject.new()

  @spec new(
          type :: power_up_types(),
          color :: Vec3.t(),
          duration :: float(),
          position :: Vec2.t(),
          texture :: Texture2D.t()
        ) :: t()
  def new(type, color, duration, position, texture) do
    %__MODULE__{
      type: type,
      duration: duration,
      game_object:
        GameObject.new(
          position,
          Vec2.new(60, 20),
          texture,
          color,
          Vec2.new(0, 150)
        )
    }
  end
end
