defmodule Breakout.BallObject do
  alias Breakout.Math.Vec2
  alias Breakout.Math.Vec3
  alias Breakout.GameObject

  @type t :: %__MODULE__{
          game_object: GameObject.t(),
          radius: number(),
          stuck: boolean(),
          sticky: boolean(),
          passthrough: boolean()
        }

  defstruct game_object: GameObject.new(),
            radius: 1,
            stuck: true,
            sticky: false,
            passthrough: false

  def new() do
    %__MODULE__{}
  end

  def new(position, radius, velocity, sprite) do
    %__MODULE__{
      radius: radius,
      game_object:
        GameObject.new(
          position,
          Vec2.new(radius * 2, radius * 2),
          sprite,
          Vec3.new(1, 1, 1),
          velocity
        )
    }
  end

  @spec reset(ball :: t(), position :: Vec2.t(), velocity :: Vec2.t()) :: t()
  def reset(ball, position, velocity) do
    new(position, ball.radius, velocity, ball.game_object.sprite)
  end

  @spec move(ball :: t(), dt :: number(), window_width :: number()) :: t()
  def move(ball, dt, window_width) do
    unless ball.stuck do
      {this_velocity_x, this_velocity_y} = this_velocity = ball.game_object.velocity
      {this_size_x, _} = ball.game_object.size

      {new_x, new_y} =
        pos =
        ball.game_object.position
        |> Vec2.add(Vec2.scale(this_velocity, dt))

      {{new_velocity_x, new_velocity_y} = new_velocity,
       {new_position_x, new_position_y} = new_position} =
        cond do
          new_x <= 0 ->
            {{-this_velocity_x, this_velocity_y}, {0.0, new_y}}

          new_x + (ball.game_object.size |> elem(0)) >= window_width ->
            {{-this_velocity_x, this_velocity_y}, {window_width - this_size_x, new_y}}

          true ->
            {this_velocity, pos}
        end

      {new_velocity, new_position} =
        if new_position_y <= 0 do
          {{new_velocity_x, -new_velocity_y}, {new_position_x, 0.0}}
        else
          {new_velocity, new_position}
        end

      b = new(new_position, ball.radius, new_velocity, ball.game_object.sprite)

      %__MODULE__{ball | game_object: b.game_object} #, radius: ball.radius, stuck: ball.stuck}
    else
      ball
    end
  end
end
