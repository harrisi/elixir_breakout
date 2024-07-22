defmodule Breakout.GameLevel do
  # alias Breakout.ResourceManager
  alias Breakout.GameObject
  alias Breakout.Math.Vec3

  @type t :: %__MODULE__{
          bricks: [GameObject.t()]
        }

  defstruct bricks: []

  def new() do
  end

  def load(file, width, height) do
    data =
      File.stream!(file)
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.split/1)
      |> Stream.map(fn row ->
        Enum.map(row, &String.to_integer/1)
      end)
      |> Enum.into([])

    init(data, width, height)
  end

  def draw(level, renderer, state) do
    Enum.each(level.bricks, fn tile ->
      unless tile.destroyed, do: GameObject.draw(tile, tile.sprite, renderer, state)
    end)
  end

  def is_completed(level) do
    Enum.any?(level, fn tile ->
      not tile.is_solid && not tile.destroyed
    end)
  end

  defp init(tile_data, level_width, level_height) do
    height = length(tile_data)
    width = length(tile_data |> hd)
    unit_width = level_width / width
    unit_height = level_height / height

    bricks =
      for {row, y} <- Enum.with_index(tile_data),
          {tile, x} <- Enum.with_index(row),
          reduce: [] do
        acc ->
          pos = {unit_width * x, unit_height * y}
          size = {unit_width, unit_height}

          case tile do
            1 ->
              # {:ok, texture} = ResourceManager.get_texture(:block_solid)
              obj = %GameObject{
                # TODO: I need to reorganize ResourceManager
                position: pos,
                size: size,
                sprite: :block_solid,
                color: Vec3.new(0.8, 0.8, 0.7),
                is_solid: true
              }

              [obj | acc]

            t when t > 1 ->
              color =
                case t do
                  2 -> Vec3.new(0.2, 0.6, 1.0)
                  3 -> Vec3.new(0, 0.7, 0)
                  4 -> Vec3.new(0.8, 0.8, 0.4)
                  5 -> Vec3.new(1, 0.5, 0)
                end

              # {:ok, texture} = ResourceManager.get_texture(:block)
              obj = %GameObject{
                position: pos,
                size: size,
                sprite: :block,
                color: color,
                # this is the default, but just to be explicit
                is_solid: false
              }

              [obj | acc]

            _ ->
              acc
          end
      end

    %__MODULE__{bricks: bricks}
  end
end
