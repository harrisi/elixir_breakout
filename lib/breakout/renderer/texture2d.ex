defmodule Breakout.Renderer.Texture2D do
  alias Breakout.ImageParser
  require Logger

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          internal_format: non_neg_integer(),
          image_format: non_neg_integer(),
          wrap_s: non_neg_integer(),
          wrap_t: non_neg_integer(),
          filter_min: non_neg_integer(),
          filter_max: non_neg_integer()
        }

  defstruct id: 0,
            width: 0,
            height: 0,
            internal_format: 0,
            image_format: 0,
            wrap_s: 0,
            wrap_t: 0,
            filter_min: 0,
            filter_max: 0

  @spec new() :: t()
  def new() do
    %__MODULE__{
      id: :gl.genTextures(1) |> hd,
      internal_format: :gl_const.gl_rgb(),
      image_format: :gl_const.gl_rgb(),
      wrap_s: :gl_const.gl_repeat(),
      wrap_t: :gl_const.gl_repeat(),
      filter_min: :gl_const.gl_linear(),
      filter_max: :gl_const.gl_linear()
    }
  end

  def load(file, alpha) do
    tex = new()

    tex =
      if alpha do
        %__MODULE__{tex | internal_format: :gl_const.gl_rgba(), image_format: :gl_const.gl_rgba()}
      else
        tex
      end

    # load file
    data =
      case File.read(file) do
        {:ok, data} -> data
        {:error, err} -> Logger.error(err: err, file: file)
      end

      IO.inspect("before parse")

    {:ok, image} = ImageParser.parse(data)

    generate(tex, image[:IHDR].width, image[:IHDR].height, image[:IDAT])
  end

  @spec generate(
          texture :: t(),
          width :: non_neg_integer(),
          height :: non_neg_integer(),
          data :: binary()
        ) :: t()
  def generate(texture, width, height, data) do
    tex = %__MODULE__{texture | width: width, height: height}

    :gl.bindTexture(:gl_const.gl_texture_2d(), tex.id)

    :gl.texImage2D(
      :gl_const.gl_texture_2d(),
      0,
      tex.internal_format,
      width,
      height,
      0,
      tex.image_format,
      :gl_const.gl_unsigned_byte(),
      data
    )

    :gl.texParameteri(:gl_const.gl_texture_2d(), :gl_const.gl_texture_wrap_s(), tex.wrap_s)
    :gl.texParameteri(:gl_const.gl_texture_2d(), :gl_const.gl_texture_wrap_t(), tex.wrap_t)

    :gl.texParameteri(
      :gl_const.gl_texture_2d(),
      :gl_const.gl_texture_min_filter(),
      tex.filter_min
    )

    :gl.texParameteri(
      :gl_const.gl_texture_2d(),
      :gl_const.gl_texture_mag_filter(),
      tex.filter_max
    )

    :gl.bindTexture(:gl_const.gl_texture_2d(), 0)

    tex
  end

  @spec bind(texture :: t()) :: :ok
  def bind(texture) do
    # IO.inspect(texture)
    :gl.bindTexture(:gl_const.gl_texture_2d(), texture.id)
    :ok
  end
end
