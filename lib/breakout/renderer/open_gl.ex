defmodule Breakout.Renderer.OpenGL do
  def init() do
    do_enables()

    :gl.blendFunc(:gl_const.gl_src_alpha(), :gl_const.gl_one_minus_src_alpha())
  end

  defp do_enables() do
    # :gl.enable(:gl_const.gl_depth_test)
    # :gl.enable(:gl_const.gl_cull_face)
    :gl.enable(:gl_const.gl_multisample())
    :gl.enable(:gl_const.gl_blend())
  end
end
