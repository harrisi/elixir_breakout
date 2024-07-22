defmodule Breakout.Renderer.Window do
  alias Breakout.Input

  defstruct [:frame, :canvas, :context]

  @type t :: %__MODULE__{
          frame: :wxFrame.wxFrame(),
          canvas: :wxGLCanvas.wxGLCanvas(),
          context: :wxGLContext.wxGLContext()
        }

  @spec init(width :: pos_integer(), height :: pos_integer()) :: t()
  def init(width, height) do
    opts = [size: {width, height}]

    wx = :wx.new()

    frame = :wxFrame.new(wx, :wx_const.wx_id_any(), ~c"Elixir Breakout", opts)

    :wxWindow.connect(frame, :close_window)

    :wxFrame.show(frame)

    gl_attrib = [
      attribList: [
        :wx_const.wx_gl_core_profile(),
        :wx_const.wx_gl_major_version(),
        4,
        :wx_const.wx_gl_minor_version(),
        1,
        :wx_const.wx_gl_doublebuffer(),
        # :wx_const.wx_gl_depth_size, 24,
        :wx_const.wx_gl_sample_buffers(),
        1,
        :wx_const.wx_gl_samples(),
        4,
        0
      ]
    ]

    canvas = :wxGLCanvas.new(frame, opts ++ gl_attrib)
    ctx = :wxGLContext.new(canvas)

    # cursor = :wxCursor.new(:wx_const.wx_cursor_blank)
    # :wxWindow.setCursor(canvas, cursor)

    # :wxWindow.captureMouse(canvas)

    :wxGLCanvas.setFocus(canvas)

    :wxGLCanvas.setCurrent(canvas, ctx)

    :wxGLCanvas.connect(canvas, :key_down, callback: &Input.handler/2)
    :wxGLCanvas.connect(canvas, :key_up, callback: &Input.handler/2)
    :wxGLCanvas.connect(canvas, :motion, callback: &Input.handler/2)
    :wxGLCanvas.connect(canvas, :mousewheel)

    %__MODULE__{
      frame: frame,
      canvas: canvas,
      context: ctx
    }
  end
end
