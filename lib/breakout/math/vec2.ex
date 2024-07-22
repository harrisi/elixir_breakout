defmodule Breakout.Math.Vec2 do
  @type t :: {float(), float()}

  @spec new(x :: number(), y :: number()) :: t()
  def new(x, y) do
    {x + 0.0, y + 0.0}
  end

  @spec add(v1 :: t(), v2 :: t()) :: t()
  def add({x1, y1}, {x2, y2}) do
    {x1 + x2, y1 + y2}
  end

  @spec subtract(v1 :: t(), v2 :: t()) :: t()
  def subtract({x1, y1}, {x2, y2}) do
    {x1 - x2, y1 - y2}
  end

  @spec scale(v :: t(), scalar :: number()) :: t()
  def scale({x, y}, scalar) do
    {x * scalar, y * scalar}
  end

  @spec multiply(v1 :: t(), v2 :: t()) :: t()
  def multiply({x1, y1}, {x2, y2}) do
    {x1 * x2, y1 * y2}
  end

  @spec normalize(v :: t()) :: t()
  def normalize({x, y} = v) do
    inv_mag = 1 / magnitude(v)
    {x * inv_mag, y * inv_mag}
  end

  @spec magnitude(v :: t()) :: float()
  def magnitude({x, y}) do
    :math.sqrt(x * x + y * y)
  end

  @spec length(v :: t()) :: float()
  def length(v) do
    magnitude(v)
  end

  @spec dot(v1 :: t(), v2 :: t()) :: float()
  def dot({x1, y1}, {x2, y2}) do
    x1 * x2 + y1 * y2
  end

  @spec clamp(value :: t(), min_val :: t(), max_val :: t()) :: t()
  def clamp({x, y}, {min_x, min_y}, {max_x, max_y}) do
    {max(min_x, min(max_x, x)), max(min_y, min(max_y, y))}
  end

  @compass [
    {0.0, 1.0},
    {1.0, 0.0},
    {0.0, -1.0},
    {-1.0, 0.0}
  ]
  @spec direction(target :: t()) :: :up | :right | :down | :left
  def direction(target) do
    target = normalize(target)

    {best_match, _} = @compass
      |> Enum.with_index()
      |> Enum.map(fn {direction, index} -> {index, dot(target, direction)} end)
      |> Enum.max_by(fn {_, dot_product} -> dot_product end)

    direction_from_index(best_match)
  end

  defp direction_from_index(0), do: :up
  defp direction_from_index(1), do: :right
  defp direction_from_index(2), do: :down
  defp direction_from_index(3), do: :left
end
