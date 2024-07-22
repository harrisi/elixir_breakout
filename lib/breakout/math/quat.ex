defmodule Breakout.Math.Quat do
  alias Breakout.Math.Vec4
  alias Breakout.Math.Vec3
  alias Breakout.Math.Mat3

  @type t :: {float(), float(), float(), float()}

  @spec new(n :: Vec3.t(), angle_rad :: number()) :: t()
  def new(n, angle_rad) do
    half_angle_rad = 0.5 * angle_rad

    w = :math.cos(half_angle_rad)
    half_sine = :math.sin(half_angle_rad)
    {x, y, z} = Vec3.normalize(n)

    {x * half_sine, y * half_sine, z * half_sine, w}
  end

  @spec multiply(lhs :: t(), rhs :: t()) :: t()
  def multiply({x1, y1, z1, w1}, {x2, y2, z2, w2}) do
    {
      x1 * w2 + w1 * x2 + y1 * z2 - z1 * y2,
      y1 * w2 + w1 * y2 + z1 * x2 - x1 * z2,
      z1 * w2 + w1 * z2 + x1 * y2 - y1 * x2,
      w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2
    }
  end

  @spec scale(quat :: t(), scalar :: float()) :: t()
  def scale({x, y, z, w}, scalar) do
    {
      x * scalar,
      y * scalar,
      z * scalar,
      w * scalar
    }
  end

  @spec normalize(quat :: t()) :: t()
  def normalize({x, y, z, w} = q) do
    inv_mag = 1 / magnitude(q)

    {
      x * inv_mag,
      y * inv_mag,
      z * inv_mag,
      w * inv_mag
    }
  end

  @spec invert(quat :: t()) :: t()
  def invert(q) do
    {x, y, z, w} = scale(q, 1 / magnitude_squared(q))

    {-x, -y, -z, w}
  end

  # this is just invert, but the C++ source does a copy. unnecessary here.
  # curious to see which is used more.
  @spec inverse(quat :: t()) :: t()
  def inverse(q) do
    invert(q)
  end

  @spec magnitude(quat :: t()) :: float()
  def magnitude(q) do
    :math.sqrt(magnitude_squared(q))
  end

  @spec magnitude_squared(quat :: t()) :: float()
  def magnitude_squared({x, y, z, w}) do
    x * x + y * y + z * z + w * w
  end

  @spec rotate_point(quat :: t(), vec :: Vec3.t()) :: Vec3.t()
  def rotate_point(q, {x, y, z}) do
    vector = {x, y, z, 0.0}

    {x, y, z, _} =
      q
      |> multiply(vector)
      |> multiply(inverse(q))

    {x, y, z}
  end

  @spec rotate_matrix(quat :: t(), mat :: Mat3.t()) :: Mat3.t()
  def rotate_matrix(q, {r0, r1, r2}) do
    {
      rotate_point(q, r0),
      rotate_point(q, r1),
      rotate_point(q, r2)
    }
  end

  @spec to_mat3(quat :: t) :: Mat3.t()
  def to_mat3(q) do
    {r0, r1, r2} = Mat3.identity()

    {
      rotate_point(q, r0),
      rotate_point(q, r1),
      rotate_point(q, r2)
    }
  end

  def to_mat4(q) do
    {{a1, a2, a3}, {b1, b2, b3}, {c1, c2, c3}} = to_mat3(q)

    {
      Vec4.new(a1, a2, a3, 0),
      Vec4.new(b1, b2, b3, 0),
      Vec4.new(c1, c2, c3, 0),
      Vec4.new(0, 0, 0, 1)
    }
  end
end
