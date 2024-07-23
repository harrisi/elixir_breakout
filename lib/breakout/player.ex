defmodule Breakout.Player do
  alias Breakout.Math.Vec2

  @type t :: %__MODULE__{
          size: Vec2.t(),
          velocity: number(),
          position: Vec2.t()
        }

  defstruct size: Vec2.new(100, 20),
            velocity: 500.0,
            position: Vec2.new(0, 0)
end
