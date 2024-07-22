defmodule Breakout.GameObject do
  alias Breakout.Renderer.Sprite
  # alias Breakout.Renderer.Texture2D
  alias Breakout.Math.Vec3
  alias Breakout.Math.Vec2

  @type t :: %__MODULE__{
          position: Vec2.t(),
          size: Vec2.t(),
          velocity: Vec2.t(),
          color: Vec3.t(),
          rotation: float(),
          is_solid: boolean(),
          destroyed: boolean(),
          sprite: atom()
        }

  defstruct position: Vec2.new(0, 0),
            size: Vec2.new(1, 1),
            velocity: Vec2.new(0, 0),
            color: Vec3.new(1, 1, 1),
            rotation: 0.0,
            is_solid: false,
            destroyed: false,
            sprite: nil

  def new() do
    %__MODULE__{}
  end

  def new(position, size, sprite, color, velocity) do
    %__MODULE__{
      position: position,
      size: size,
      sprite: sprite,
      color: color,
      velocity: velocity
    }
  end

  def draw(
        %__MODULE__{
          sprite: sprite,
          position: position,
          size: size,
          rotation: rotation,
          color: color
        } = game_object,
        name,
        _renderer,
        state
      ) do
    # IO.inspect(game_object, label: "game_object draw")
    Sprite.draw(state, name, position, size, rotation, color)
  end

  def check_collision(%__MODULE__{position: {ax, ay}, size: {aw, ah}}, %__MODULE__{position: {bx, by}, size: {bw, bh}}) do
    collision_x = ax + aw >= bx and bx + bw >= ax
    collision_y = ay + ah >= by and by + bh >= ay

    collision_x and collision_y
  end

  def check_collision(%{game_object: %{position: ball_position}, radius: radius}, %__MODULE__{size: {w, h}, position: {x, y}}) do
    center = Vec2.add(ball_position, Vec2.new(radius, radius))

    {aabb_half_x, aabb_half_y} = aabb_half_extents = Vec2.new(w / 2, h / 2)
    aabb_center = Vec2.new(x + aabb_half_x, y + aabb_half_y)

    diff = Vec2.subtract(center, aabb_center)

    clamped = Vec2.clamp(diff, Vec2.scale(aabb_half_extents, -1.0), aabb_half_extents)

    closest = Vec2.add(aabb_center, clamped)

    diff = Vec2.subtract(closest, center)

    if Vec2.length(diff) < radius do
      {true, Vec2.direction(diff), diff}
    else
      {false, :up, Vec2.new(0, 0)}
    end
  end
end
