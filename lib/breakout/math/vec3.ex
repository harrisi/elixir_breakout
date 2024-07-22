defmodule Breakout.Math.Vec3 do
  @type t :: {float(), float(), float()}

  @spec new(x :: number(), y :: number(), z :: number()) :: t()
  def new(x, y, z) do
    {x + 0.0, y + 0.0, z + 0.0}
  end

  @spec add(vec1 :: t(), vec2 :: t()) :: t()
  def add({x1, y1, z1}, {x2, y2, z2}) do
    {x1 + x2, y1 + y2, z1 + z2}
  end

  @spec cross(vec1 :: t(), vec2 :: t()) :: t()
  def cross({x1, y1, z1}, {x2, y2, z2}) do
    {
      y1 * z2 - z1 * y2,
      z1 * x2 - x1 * z2,
      x1 * y2 - y1 * x2
    }
  end

  @spec dot(vec1 :: t(), vec2 :: t()) :: float()
  def dot({x1, y1, z1}, {x2, y2, z2}) do
    x1 * x2 + y1 * y2 + z1 * z2
  end

  @spec normalize(vec :: t()) :: t()
  def normalize({x, y, z} = vec) do
    mag = magnitude(vec)
    inv_mag = if mag == 0.0, do: 0, else: 1 / mag
    {x * inv_mag, y * inv_mag, z * inv_mag}
  end

  @spec magnitude(vec :: t()) :: float()
  def magnitude({x, y, z}) do
    :math.sqrt(x * x + y * y + z * z)
  end

  @spec scale(vec :: t(), scalar :: float()) :: t()
  def scale({x, y, z}, scalar) do
    {x * scalar, y * scalar, z * scalar}
  end

  @spec get_ortho(this :: t()) :: {t(), t()}
  def get_ortho(n) do
    n = normalize(n)
    {_, _, nz} = n
    w = if nz * nz > 0.9 * 0.9, do: new(1, 0, 0), else: new(0, 0, 1)
    u = normalize(cross(w, n))
    v = normalize(cross(n, u))
    u = normalize(cross(v, n))

    {u, v}
  end

  @spec subtract(vec1 :: t(), vec2 :: t()) :: t()
  def subtract({x1, y1, z1}, {x2, y2, z2}) do
    {x1 - x2, y1 - y2, z1 - z2}
  end

  @spec to_binary(vec :: t()) :: binary()
  def to_binary({x, y, z}) do
    <<x::float-native-size(32), y::float-native-size(32), z::float-native-size(32)>>
  end
end
