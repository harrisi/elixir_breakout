defmodule Breakout.Math.Mat2 do
  alias Breakout.Math.Vec2

  @type t :: {Vec2.t(), Vec2.t()}

  @spec flatten(matrix :: t()) ::
          {float(), float(), float(), float()}
  def flatten({{a0, a1}, {b0, b1}}) do
    {a0, a1, b0, b1}
  end

  @spec scale(mat :: t(), scalar :: number()) :: t()
  def scale({r0, r1}, scalar) do
    {Vec2.scale(r0, scalar), Vec2.scale(r1, scalar)}
  end

  @spec add(mat1 :: t(), mat2 :: t()) :: t()
  def add({r0, r1}, {s0, s1}) do
    {Vec2.add(r0, s0), Vec2.add(r1, s1)}
  end

  @spec determinant(mat :: t()) :: float()
  def determinant({{r0x, r0y}, {r1x, r1y}}) do
    r0x * r1y - r0y * r1x
  end
end
