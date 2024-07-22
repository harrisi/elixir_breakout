-module(wx_const).
-compile(nowarn_export_all).
-compile(export_all).

-include_lib("wx/include/wx.hrl").

wx_id_any() -> ?wxID_ANY.
wx_gl_rgba() -> ?WX_GL_RGBA.

wx_gl_doublebuffer() -> ?WX_GL_DOUBLEBUFFER.
wx_gl_depth_size() -> ?WX_GL_DEPTH_SIZE.
wx_gl_forward_compat() -> ?WX_GL_FORWARD_COMPAT.

wxk_left() -> ?WXK_LEFT.
wxk_right() -> ?WXK_RIGHT.
wxk_up() -> ?WXK_UP.
wxk_down() -> ?WXK_DOWN.
wxk_space() -> ?WXK_SPACE.
wxk_raw_control() -> ?WXK_RAW_CONTROL.

wx_gl_major_version() -> ?WX_GL_MAJOR_VERSION.

wx_gl_minor_version() -> ?WX_GL_MINOR_VERSION.

wx_gl_core_profile() -> ?WX_GL_CORE_PROFILE.
wx_gl_sample_buffers() -> ?WX_GL_SAMPLE_BUFFERS.

wx_gl_samples() -> ?WX_GL_SAMPLES.

wx_null_cursor() -> ?wxNullCursor.
wx_cursor_blank() -> ?wxCURSOR_BLANK.
wx_cursor_cross() -> ?wxCURSOR_CROSS.