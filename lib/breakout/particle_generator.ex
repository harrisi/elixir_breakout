defmodule Breakout.ParticleGenerator do
  alias Breakout.Math.Vec2
  alias Breakout.GameObject
  alias Breakout.Renderer.Texture2D
  alias Breakout.Renderer.Shader
  alias Breakout.Particle
  alias Breakout.GameObject
  alias Breakout.Util

  defstruct [
    particles: [],
    amount: 0,
    shader: nil,
    texture: nil,
    vao: 0,
  ]

  @type t :: %__MODULE__{
    particles: [Particle.t()],
    amount: non_neg_integer(),
    shader: Shader.t(),
    texture: Texture2D.t(),
    vao: non_neg_integer(),
  }

  @spec new(shader :: Shader.t(), texture :: Texture2D.t(), amount :: non_neg_integer(), vao :: non_neg_integer()) :: t()
  def new(shader, texture, amount, vao) do
    %__MODULE__{
      particles: [],
      amount: amount,
      shader: shader,
      texture: texture,
      vao: vao,
    }
    |> init()
  end

  @spec update(pg :: t(), dt :: float(), object :: GameObject.t(), new_particles :: non_neg_integer(), offset :: Vec2.t()) :: t()
  def update(pg, dt, object, new_particles, offset) do
    %__MODULE__{}
  end

  def draw(pg) do

  end

  defp init(pg) do
    particle_quad = Util.make_bits([
      0, 1, 0, 1,
      1, 0, 1, 0,
      0, 0, 0, 0,

      0, 1, 0, 1,
      1, 1, 1, 1,
      1, 0, 1, 0,
    ])
    [vao] = :gl.genVertexArrays(1)
    [vbo] = :gl.genBuffers(1)
    :gl.bindVertexArray(vao)

    :gl.bindBuffer(:gl_const.gl_array_buffer, vbo)
    :gl.bufferData(:gl_const.gl_array_buffer, byte_size(particle_quad), particle_quad, :gl_const.gl_static_draw)

    :gl.enableVertexAttribArray(0)
    :gl.vertexAttribPointer(0, 4, :gl_const.gl_float, :gl_const.gl_false, 4 * byte_size(<<0::float-native-size(32)>>), 0)
    :gl.bindVertexArray(0)

    particles = for _ <- 0..pg.amount do
      %Particle{}
    end

    %__MODULE__{pg |
      vao: vao,
      particles: particles,
    }
  end

  defp first_unused_particle(pg) do

  end

  defp respawn_particle(pg, particle, object, offset) do

  end
end
