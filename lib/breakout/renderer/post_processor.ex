defmodule Breakout.Renderer.PostProcessor do
  require Logger
  alias Breakout.Util
  alias Breakout.Renderer.{Shader, Texture2D}

  @type t :: %__MODULE__{
          shader: Shader.t(),
          texture: Texture2D.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          confuse: boolean(),
          chaos: boolean(),
          shake: boolean(),
          msfbo: non_neg_integer(),
          fbo: non_neg_integer(),
          rbo: non_neg_integer(),
          vao: non_neg_integer()
        }

  defstruct shader: nil,
            texture: nil,
            width: 0,
            height: 0,
            confuse: false,
            chaos: false,
            shake: false,
            msfbo: 0,
            fbo: 0,
            rbo: 0,
            vao: 0

  @spec new(shader :: Shader.t(), width :: non_neg_integer(), height :: non_neg_integer()) :: t()
  def new(shader, width, height) do
    pp = %__MODULE__{
      shader: shader,
      width: width,
      height: height
    }

    [msfbo, fbo] = :gl.genFramebuffers(2)
    :gl.isFramebuffer(msfbo)
    :gl.isFramebuffer(fbo)
    [rbo] = :gl.genRenderbuffers(1)
    :gl.isRenderbuffer(rbo)

    :gl.bindFramebuffer(:gl_const.gl_framebuffer(), msfbo)

    :gl.flush()

    :gl.bindRenderbuffer(:gl_const.gl_renderbuffer(), rbo)

    :gl.renderbufferStorageMultisample(
      :gl_const.gl_renderbuffer(),
      4,
      :gl_const.gl_rgb(),
      width,
      height
    )

    :gl.framebufferRenderbuffer(
      :gl_const.gl_framebuffer(),
      :gl_const.gl_color_attachment0(),
      :gl_const.gl_renderbuffer(),
      rbo
    )

    if :gl.checkFramebufferStatus(:gl_const.gl_framebuffer()) !=
         :gl_const.gl_framebuffer_complete() do
      Logger.error("failed to init msfbo")
    end

    :gl.bindFramebuffer(:gl_const.gl_framebuffer(), fbo)

    tex =
      Texture2D.new()
      |> Texture2D.generate(width, height, 0)

    :gl.framebufferTexture2D(
      :gl_const.gl_framebuffer(),
      :gl_const.gl_color_attachment0(),
      :gl_const.gl_texture_2d(),
      tex.id,
      0
    )

    pp = %__MODULE__{pp | texture: tex, msfbo: msfbo, fbo: fbo, rbo: rbo}

    if :gl.checkFramebufferStatus(:gl_const.gl_framebuffer()) !=
         :gl_const.gl_framebuffer_complete() do
      Logger.error("failed to init fbo")
    end

    :gl.bindFramebuffer(:gl_const.gl_framebuffer(), 0)

    pp = init_render_data(pp)

    Shader.set(pp.shader, ~c"scene", 0, true)
    offset = 1.0 / 300.0

    offsets = [
      {-offset, offset},
      {0.0, offset},
      {offset, offset},
      {-offset, 0.0},
      {0.0, 0.0},
      {offset, 0.0},
      {-offset, -offset},
      {0.0, -offset},
      {offset, -offset}
    ]

    Shader.set(pp.shader, ~c"offsets", offsets)

    edge_kernel = [
      -1,
      -1,
      -1,
      -1,
      8,
      -1,
      -1,
      -1,
      -1
    ]

    Shader.set(pp.shader, ~c"edge_kernel", edge_kernel)

    blur_kernel = [
      1 / 16,
      2 / 16,
      1 / 16,
      2 / 16,
      4 / 16,
      2 / 16,
      1 / 16,
      2 / 16,
      1 / 16
    ]

    Shader.set(pp.shader, ~c"blur_kernel", blur_kernel)

    pp
  end

  @spec begin_render(post_processor :: t()) :: :ok
  def begin_render(%__MODULE__{msfbo: msfbo}) do
    :gl.bindFramebuffer(:gl_const.gl_framebuffer(), msfbo)
    :gl.clearColor(0.0, 0.0, 0.0, 1.0)
    :gl.clear(:gl_const.gl_color_buffer_bit())
  end

  @spec end_render(post_processor :: t()) :: :ok
  def end_render(%__MODULE__{msfbo: msfbo, fbo: fbo, width: width, height: height}) do
    :gl.bindFramebuffer(:gl_const.gl_read_framebuffer(), msfbo)
    :gl.bindFramebuffer(:gl_const.gl_draw_framebuffer(), fbo)

    :gl.blitFramebuffer(
      0,
      0,
      width,
      height,
      0,
      0,
      width,
      height,
      :gl_const.gl_color_buffer_bit(),
      :gl_const.gl_nearest()
    )

    :gl.bindFramebuffer(:gl_const.gl_framebuffer(), 0)
  end

  @spec render(post_processor :: t(), time :: float()) :: :ok
  def render(
        %__MODULE__{
          shader: shader,
          confuse: confuse,
          chaos: chaos,
          shake: shake,
          texture: texture,
          vao: vao
        },
        time
      )
      when is_float(time) do
    Shader.use_shader(shader)
    |> Shader.set(~c"time", time)
    |> Shader.set(~c"confuse", confuse)
    |> Shader.set(~c"chaos", chaos)
    |> Shader.set(~c"shake", shake)

    :gl.activeTexture(:gl_const.gl_texture0())
    Texture2D.bind(texture)

    :gl.bindVertexArray(vao)
    :gl.drawArrays(:gl_const.gl_triangles(), 0, 6)
    :gl.bindVertexArray(0)
  end

  @spec init_render_data(post_processor :: t()) :: t()
  def init_render_data(%__MODULE__{} = post_processor) do
    vertices =
      Util.make_bits([
        -1,
        -1,
        0,
        0,
        1,
        1,
        1,
        1,
        -1,
        1,
        0,
        1,
        -1,
        -1,
        0,
        0,
        1,
        -1,
        1,
        0,
        1,
        1,
        1,
        1
      ])

    [vao] = :gl.genVertexArrays(1)
    [vbo] = :gl.genBuffers(1)

    :gl.bindBuffer(:gl_const.gl_array_buffer(), vbo)

    :gl.bufferData(
      :gl_const.gl_array_buffer(),
      byte_size(vertices),
      vertices,
      :gl_const.gl_static_draw()
    )

    :gl.bindVertexArray(vao)
    :gl.enableVertexAttribArray(0)

    :gl.vertexAttribPointer(
      0,
      4,
      :gl_const.gl_float(),
      :gl_const.gl_false(),
      4 * byte_size(<<0.0::native-float-size(32)>>),
      0
    )

    :gl.bindBuffer(:gl_const.gl_array_buffer(), 0)
    :gl.bindVertexArray(0)

    %__MODULE__{post_processor | vao: vao}
  end
end
