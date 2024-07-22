defmodule Breakout.Math.Mat3 do
  alias Breakout.Math.Mat2
  alias Breakout.Math.Vec3

  @type t :: {Vec3.t(), Vec3.t(), Vec3.t()}

  @spec flatten(matrix :: t()) ::
          {float(), float(), float(), float(), float(), float(), float(), float(), float()}
  def flatten({{a0, a1, a2}, {b0, b1, b2}, {c0, c1, c2}}) do
    {a0, a1, a2, b0, b1, b2, c0, c1, c2}
  end

  @spec zero() :: t()
  def zero() do
    {
      Vec3.new(0, 0, 0),
      Vec3.new(0, 0, 0),
      Vec3.new(0, 0, 0)
    }
  end

  @spec identity() :: t()
  def identity() do
    {
      Vec3.new(1, 0, 0),
      Vec3.new(0, 1, 0),
      Vec3.new(0, 0, 1)
    }
  end

  @spec scale(mat :: t(), scalar :: number()) :: t()
  def scale({r0, r1, r2}, scalar) do
    {
      Vec3.scale(r0, scalar),
      Vec3.scale(r1, scalar),
      Vec3.scale(r2, scalar)
    }
  end

  @spec add(mat1 :: t(), mat2 :: t()) :: t()
  def add({r0, r1, r2}, {s0, s1, s2}) do
    {
      Vec3.add(r0, s0),
      Vec3.add(r1, s1),
      Vec3.add(r2, s2)
    }
  end

  @spec trace(mat :: t()) :: float()
  def trace({{r0x, _, _}, {_, r1y, _}, {_, _, r2z}}) do
    r0x * r0x + r1y * r1y + r2z * r2z
  end

  @spec determinant(mat :: t()) :: float()
  def determinant({{r0x, r0y, r0z}, {r1x, r1y, r1z}, {r2x, r2y, r2z}}) do
    i = r0x * (r1y * r2z - r1z * r2y)
    j = r0y * (r1x * r2z - r1z * r2x)
    k = r0z * (r1x * r2y - r1y * r2x)

    i - j + k
  end

  @spec transpose(mat :: t()) :: t()
  def transpose({
        {r0x, r0y, r0z},
        {r1x, r1y, r1z},
        {r2x, r2y, r2z}
      }) do
    {
      {r0x, r1x, r2x},
      {r0y, r1y, r2y},
      {r0z, r1z, r2z}
    }
  end

  @spec inverse(mat :: t()) :: t()
  def inverse(m) do
    inv = {
      {cofactor(m, 0, 0), cofactor(m, 1, 0), cofactor(m, 2, 0)},
      {cofactor(m, 0, 1), cofactor(m, 1, 1), cofactor(m, 2, 1)},
      {cofactor(m, 0, 2), cofactor(m, 1, 2), cofactor(m, 2, 2)}
    }

    inv_det = 1 / determinant(m)

    scale(inv, inv_det)
  end

  @spec minor(mat :: t(), i :: integer(), j :: integer()) :: Mat2.t()
  def minor(mat, i, j) do
    rows = Tuple.to_list(mat)

    minor_rows =
      rows
      |> Enum.with_index()
      |> Enum.reject(fn {_row, y} -> y == j end)
      |> Enum.map(fn {row, _y} ->
        row
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reject(fn {_value, x} -> x == i end)
        |> Enum.map(&elem(&1, 0))
        |> List.to_tuple()
      end)

    List.to_tuple(minor_rows)
  end

  @spec cofactor(mat :: t(), i :: integer(), j :: integer()) :: float()
  def cofactor(mat, i, j) do
    :math.pow(-1, i + 1 + j + 1) * Mat2.determinant(minor(mat, i, j))
  end

  @spec to_binary(matrix :: t()) :: binary()
  def to_binary({a, b, c}) do
    Vec3.to_binary(a) <> Vec3.to_binary(b) <> Vec3.to_binary(c)
  end
end
