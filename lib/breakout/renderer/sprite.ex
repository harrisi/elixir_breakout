defmodule Breakout.Renderer.Sprite do
  alias Breakout.Renderer.Texture2D
  alias Breakout.Math.Vec3
  alias Breakout.Math.Mat4
  alias Breakout.Renderer.Shader
  alias Breakout.Util

  defstruct [:shader, :quadVAO]

  def new(shader) do
    %__MODULE__{
      shader: shader
    }
    |> init_render_data()
  end

  def draw(
        # %__MODULE__{shader: shader} = sprite,
        %_{sprite_renderer: %{shader: shader} = sprite, resources: resources},
        texture,
        {x, y} = _position,
        {width, height} = _size,
        rotate,
        color
      ) do

    # shader = resources.shaders[shader] |> IO.inspect(label: "shader")
    texture = resources.textures[texture]
    Shader.use_shader(shader)

    model =
      Mat4.identity()
      |> Mat4.translate(Vec3.new(x, y, 0))
      |> Mat4.translate(Vec3.new(0.5 * width, 0.5 * height, 0))
      |> Mat4.rotate(rotate, Vec3.new(0, 0, 1))
      |> Mat4.translate(Vec3.new(-0.5 * width, -0.5 * height, 0))
      |> Mat4.scale_vec(Vec3.new(width, height, 1))
      |> Mat4.transpose()

    Shader.set(shader, ~c"model", model |> Mat4.flatten())
    Shader.set(shader, ~c"spriteColor", color)

    :gl.activeTexture(:gl_const.gl_texture0())
    Texture2D.bind(texture)

    :gl.bindVertexArray(sprite.quadVAO)
    :gl.drawArrays(:gl_const.gl_triangles(), 0, 6)

    :gl.bindVertexArray(0)
  end

  defp init_render_data(%__MODULE__{} = sprite) do
    [quadVAO] = :gl.genVertexArrays(1)
    sprite = %__MODULE__{sprite | quadVAO: quadVAO}

    vertices =
      Util.make_bits([
        0.0,
        1.0,
        0.0,
        1.0,
        1.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        0.0,
        1.0,
        0.0
      ])

    [vbo] = :gl.genBuffers(1)

    :gl.bindBuffer(:gl_const.gl_array_buffer(), vbo)

    :gl.bufferData(
      :gl_const.gl_array_buffer(),
      byte_size(vertices),
      vertices,
      :gl_const.gl_static_draw()
    )

    :gl.bindVertexArray(quadVAO)
    :gl.enableVertexAttribArray(0)

    :gl.vertexAttribPointer(
      0,
      4,
      :gl_const.gl_float(),
      :gl_const.gl_false(),
      4 * byte_size(<<0::native-float-size(32)>>),
      0
    )

    :gl.bindBuffer(:gl_const.gl_array_buffer(), 0)
    :gl.bindVertexArray(0)

    sprite
  end
end
