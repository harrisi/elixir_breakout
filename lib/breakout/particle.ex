defmodule Breakout.Particle do
  alias Breakout.Math.Vec2
  alias Breakout.Math.Vec4

  defstruct position: Vec2.new(0, 0),
            velocity: Vec2.new(0, 0),
            color: Vec4.new(1, 1, 1, 1),
            life: 0.0

  @type t :: %__MODULE__{
          position: Vec2.t(),
          velocity: Vec2.t(),
          color: Vec4.t(),
          life: float()
        }
end
