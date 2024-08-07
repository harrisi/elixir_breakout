defmodule Breakout.State do
  alias Breakout.PowerUp
  alias Breakout.Renderer.PostProcessor
  alias Breakout.ParticleGenerator
  alias Breakout.Renderer.Shader
  alias Breakout.BallObject
  alias Breakout.Renderer.Texture2D
  alias Breakout.GameObject
  alias Breakout.GameLevel

  @game_width 1200
  @game_height 800

  @type game_state :: :active | :menu | :win | nil

  @type t :: %__MODULE__{
          game_state: game_state(),
          keys: MapSet.t(integer()),
          keys_processed: MapSet.t(integer()),
          width: pos_integer(),
          height: pos_integer(),
          window: :wxWindow.wxWindow() | nil,
          t: pos_integer(),
          dt: non_neg_integer(),
          shader_program: non_neg_integer(),
          sprite_renderer: non_neg_integer(),
          levels: [GameLevel.t()],
          level: non_neg_integer(),
          player: GameObject.t(),
          background_texture: Texture2D.t(),
          ball: BallObject.t(),
          resources: %{shaders: %{atom() => Shader.t()}, textures: %{atom() => Texture2D.t()}},
          particle_generator: ParticleGenerator.t(),
          post_processor: PostProcessor.t(),
          elapsed: float(),
          start: float(),
          shake_time: float(),
          power_ups: [PowerUp.t()],
          font: :wxFont.wxFont(),
          brush: :wxBrush.wxBrush(),
          lives: pos_integer(),
          menu_string_size: {non_neg_integer(), non_neg_integer()},
        }

  defstruct [
    # :active | :menu | :win
    game_state: :active,
    keys: MapSet.new(),
    keys_processed: MapSet.new(),
    width: @game_width,
    height: @game_height,
    window: nil,
    t: 0,
    dt: 0,
    shader_program: 0,
    sprite_renderer: 0,
    levels: [],
    level: 0,
    player: GameObject.new(),
    background_texture: nil,
    ball: BallObject.new(),
    resources: %{shaders: %{}, textures: %{}},
    particle_generator: nil,
    post_processor: nil,
    elapsed: 0.0,
    start: 0.0,
    shake_time: 0.0,
    power_ups: [],
    font: nil,
    brush: nil,
    lives: 3,
    menu_string_size: {200, 200},
  ]
end
