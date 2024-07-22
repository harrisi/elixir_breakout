defmodule Breakout.Math.Vec4 do
  @type t :: {float(), float(), float(), float()}

  @spec new(x :: number(), y :: number(), z :: number(), w :: number()) :: t()
  def new(x, y, z, w) do
    {x + 0.0, y + 0.0, z + 0.0, w + 0.0}
  end

  @spec add(vec1 :: t(), vec2 :: t()) :: t()
  def add({x1, y1, z1, w1}, {x2, y2, z2, w2}) do
    {x1 + x2, y1 + y2, z1 + z2, w1 + w2}
  end

  @spec normalize(vec :: t()) :: t()
  def normalize({x, y, z, w} = vec) do
    inv_mag = 1 / magnitude(vec)
    {x * inv_mag, y * inv_mag, z * inv_mag, w * inv_mag}
  end

  @spec magnitude(vec :: t()) :: float()
  def magnitude({x, y, z, w}) do
    :math.sqrt(x * x + y * y + z * z + w * w)
  end

  @spec scale(vec :: t(), scalar :: float()) :: t()
  def scale({x, y, z, w}, scalar) do
    {x * scalar, y * scalar, z * scalar, w * scalar}
  end

  @spec subtract(vec1 :: t(), vec2 :: t()) :: t()
  def subtract({x1, y1, z1, w1}, {x2, y2, z2, w2}) do
    {x1 - x2, y1 - y2, z1 - z2, w1 - w2}
  end

  @spec dot(vec1 :: t(), vec2 :: t()) :: float()
  def dot({x1, y1, z1, w1}, {x2, y2, z2, w2}) do
    x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2
  end

  @spec to_binary(vec :: t()) :: binary()
  def to_binary({x, y, z, w}) do
    <<x::float-native-size(32), y::float-native-size(32), z::float-native-size(32),
      w::float-native-size(32)>>
  end
end
