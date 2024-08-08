-module(gl_const).
-compile(nowarn_export_all).
-compile(export_all).

-include_lib("wx/include/gl.hrl").

gl_depth_test() -> ?GL_DEPTH_TEST.

gl_lequal() -> ?GL_LEQUAL.
gl_color_buffer_bit() -> ?GL_COLOR_BUFFER_BIT.

gl_depth_buffer_bit() -> ?GL_DEPTH_BUFFER_BIT.

gl_triangles() -> ?GL_TRIANGLES.
gl_array_buffer() -> ?GL_ARRAY_BUFFER.
gl_element_array_buffer() -> ?GL_ELEMENT_ARRAY_BUFFER.
gl_static_draw() -> ?GL_STATIC_DRAW.

gl_vertex_shader() -> ?GL_VERTEX_SHADER.
gl_fragment_shader() -> ?GL_FRAGMENT_SHADER.

gl_compile_status() -> ?GL_COMPILE_STATUS.
gl_link_status() -> ?GL_LINK_STATUS.

gl_float() -> ?GL_FLOAT.
gl_false() -> ?GL_FALSE.
gl_true() -> ?GL_TRUE.
gl_unsigned_int() -> ?GL_UNSIGNED_INT.
gl_unsigned_byte() -> ?GL_UNSIGNED_BYTE.

gl_front_and_back() -> ?GL_FRONT_AND_BACK.
gl_line() -> ?GL_LINE.
gl_fill() -> ?GL_FILL.
gl_debug_output() -> ?GL_DEBUG_OUTPUT.
gl_texture_2d() -> ?GL_TEXTURE_2D.
gl_texture_wrap_s() -> ?GL_TEXTURE_WRAP_S.
gl_texture_wrap_t() -> ?GL_TEXTURE_WRAP_T.
gl_texture_min_filter() -> ?GL_TEXTURE_MIN_FILTER.
gl_texture_mag_filter() -> ?GL_TEXTURE_MAG_FILTER.
gl_rgb() -> ?GL_RGB.
gl_rgba() -> ?GL_RGBA.
gl_multisample() -> ?GL_MULTISAMPLE.
gl_luminance() -> ?GL_LUMINANCE.

gl_texture0() -> ?GL_TEXTURE0.

gl_cull_face() -> ?GL_CULL_FACE.
gl_back() -> ?GL_BACK.
gl_front() -> ?GL_FRONT.
gl_ccw() -> ?GL_CCW.
gl_cw() -> ?GL_CW.

gl_info_log_length() -> ?GL_INFO_LOG_LENGTH.

gl_blend() -> ?GL_BLEND.
gl_src_alpha() -> ?GL_SRC_ALPHA.
gl_one() -> ?GL_ONE.
gl_one_minus_src_alpha() -> ?GL_ONE_MINUS_SRC_ALPHA.

gl_repeat() -> ?GL_REPEAT.
gl_linear() -> ?GL_LINEAR.
gl_nearest() -> ?GL_NEAREST.

gl_framebuffer() -> ?GL_FRAMEBUFFER.
gl_renderbuffer() -> ?GL_RENDERBUFFER.
gl_color_attachment0() -> ?GL_COLOR_ATTACHMENT0.
gl_framebuffer_complete() -> ?GL_FRAMEBUFFER_COMPLETE.
gl_read_framebuffer() -> ?GL_READ_FRAMEBUFFER.
gl_draw_framebuffer() -> ?GL_DRAW_FRAMEBUFFER.

gl_texture_env() -> ?GL_TEXTURE_ENV.
gl_texture_env_mode() -> ?GL_TEXTURE_ENV_MODE.
gl_replace() -> ?GL_REPLACE.