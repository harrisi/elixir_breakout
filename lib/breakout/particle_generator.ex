defmodule Breakout.ParticleGenerator do
  alias Breakout.Math.Vec4
  alias Breakout.Math.Vec2
  alias Breakout.GameObject
  alias Breakout.Renderer.Texture2D
  alias Breakout.Renderer.Shader
  alias Breakout.Particle
  alias Breakout.GameObject
  alias Breakout.Util

  defstruct particles: [],
            amount: 0,
            shader: nil,
            texture: nil,
            vao: 0

  @type t :: %__MODULE__{
          particles: [Particle.t()],
          amount: non_neg_integer(),
          shader: Shader.t(),
          texture: Texture2D.t(),
          vao: non_neg_integer()
        }

  @spec new(shader :: Shader.t(), texture :: Texture2D.t(), amount :: non_neg_integer()) :: t()
  def new(shader, texture, amount) do
    %__MODULE__{
      particles: [],
      amount: amount,
      shader: shader,
      texture: texture
    }
    |> init()
  end

  @spec update(
          pg :: t(),
          dt :: float(),
          object :: GameObject.t(),
          new_particles :: non_neg_integer(),
          offset :: Vec2.t()
        ) :: t()
  def update(pg, dt, object, new_particles, offset) do
    generator =
      Enum.reduce(1..new_particles, pg, fn _, acc ->
        unused_particle = first_unused_particle(acc)
        respawn_particle(acc, unused_particle, object, offset)
      end)

    generator =
      Enum.reduce(0..(generator.amount - 1)//1, generator, fn i, acc ->
        particle = Enum.at(acc.particles, i)
        updated_particle = update_particle(particle, dt)
        update_in(acc.particles[i], fn _ -> updated_particle end)
      end)

    generator
  end

  def update_particle(%Particle{} = particle, dt) do
    life = particle.life - dt

    if life > 0 do
      position = Vec2.subtract(particle.position, Vec2.scale(particle.velocity, dt))
      color = put_elem(particle.color, 3, (particle.color |> elem(3)) - dt * 2.5)
      %Particle{particle | position: position, color: color, life: life}
    else
      particle
    end
  end

  def draw(%__MODULE__{} = pg) do
    :gl.blendFunc(:gl_const.gl_src_alpha(), :gl_const.gl_one())
    Shader.use_shader(pg.shader)

    Enum.each(pg.particles, fn particle ->
      if particle.life > 0 do
        pg.shader
        |> Shader.set(~c"offset", particle.position)
        |> Shader.set(~c"color", particle.color)

        Texture2D.bind(pg.texture)

        :gl.bindVertexArray(pg.vao)
        :gl.drawArrays(:gl_const.gl_triangles(), 0, 6)
        :gl.bindVertexArray(0)
      end
    end)

    :gl.blendFunc(:gl_const.gl_src_alpha(), :gl_const.gl_one_minus_src_alpha())
  end

  defp init(pg) do
    particle_quad =
      Util.make_bits([
        0,
        1,
        0,
        1,
        1,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        1,
        1,
        1,
        1,
        1,
        1,
        0,
        1,
        0
      ])

    [vao] = :gl.genVertexArrays(1)
    [vbo] = :gl.genBuffers(1)
    :gl.bindVertexArray(vao)

    :gl.bindBuffer(:gl_const.gl_array_buffer(), vbo)

    :gl.bufferData(
      :gl_const.gl_array_buffer(),
      byte_size(particle_quad),
      particle_quad,
      :gl_const.gl_static_draw()
    )

    :gl.enableVertexAttribArray(0)

    :gl.vertexAttribPointer(
      0,
      4,
      :gl_const.gl_float(),
      :gl_const.gl_false(),
      4 * byte_size(<<0::float-native-size(32)>>),
      0
    )

    :gl.bindVertexArray(0)

    particles =
      for _ <- 0..pg.amount do
        %Particle{}
      end

    %__MODULE__{pg | vao: vao, particles: particles}
  end

  defp first_unused_particle(%__MODULE__{particles: particles}) do
    Enum.find_index(particles, fn p -> p.life <= 0 end) || 0
  end

  defp respawn_particle(%__MODULE__{} = pg, index, %GameObject{} = object, offset) do
    random = (:rand.uniform(100) - 50) / 10.0
    r_color = 0.5 + :rand.uniform(100) / 100.0
    position = Vec2.add(object.position, {random + offset, random + offset})
    color = Vec4.new(r_color, r_color, r_color, 1)
    velocity = Vec2.scale(object.velocity, 0.1)

    particle = %Particle{position: position, color: color, life: 1.0, velocity: velocity}
    update_in(pg.particles[index], fn _ -> particle end)
  end
end
