defmodule Breakout.Renderer.Shader do
  require Logger

  @type t :: integer()
  @type shader_type :: non_neg_integer()
  @type uniform_type ::
          float()
          | integer()
          # Breakout.Vec2.t() | Breakout.Vec3.t() | Breakout.Vec4.t() | Breakout.Mat4.t()
          | {float(), float()}
          | {float(), float(), float()}
          | {float(), float(), float(), float()}

  @spec init(vertex_path :: Path.t(), fragment_path :: Path.t()) :: t()
  def init(vertex_path, fragment_path) do
    vertex_code = File.read!(vertex_path)
    fragment_code = File.read!(fragment_path)

    vertex_shader = compile_shader(vertex_code, :gl_const.gl_vertex_shader())
    fragment_shader = compile_shader(fragment_code, :gl_const.gl_fragment_shader())

    shader_program = :gl.createProgram()
    :gl.attachShader(shader_program, vertex_shader)
    :gl.attachShader(shader_program, fragment_shader)
    :gl.linkProgram(shader_program)
    check_program_linking!(shader_program)

    :gl.deleteShader(vertex_shader)
    :gl.deleteShader(fragment_shader)

    shader_program
  end

  @spec compile_shader(source :: binary(), type :: shader_type()) :: t()
  defp compile_shader(source, type) do
    shader = :gl.createShader(type)
    :gl.shaderSource(shader, [source <> <<0>>])
    :gl.compileShader(shader)
    check_shader_compilation!(shader)

    shader
  end

  @spec check_shader_compilation!(shader :: integer()) :: :ok
  defp check_shader_compilation!(shader) do
    status = :gl.getShaderiv(shader, :gl_const.gl_compile_status())

    unless status == :gl_const.gl_true() do
      buf_size = :gl.getShaderiv(shader, :gl_const.gl_info_log_length())
      info_log = :gl.getShaderInfoLog(shader, buf_size)
      Logger.error(msg: info_log)
      raise "Shader compilation error: #{info_log}"
    end

    :ok
  end

  @spec check_program_linking!(program :: integer()) :: :ok
  defp check_program_linking!(program) do
    status = :gl.getProgramiv(program, :gl_const.gl_link_status())

    unless status == :gl_const.gl_true() do
      buf_size = :gl.getProgramiv(program, :gl_const.gl_info_log_length())
      info_log = :gl.getProgramInfoLog(program, buf_size)
      Logger.error(msg: info_log)
      raise "Program linking error: #{info_log}"
    end

    :ok
  end

  @spec use_shader(shader :: t()) :: t()
  def use_shader(shader) do
    :gl.useProgram(shader)

    shader
  end

  # @spec set(shader :: pos_integer(), name :: binary(), value :: uniform_type()) :: :ok
  def set(shader, name, value, use_shader \\ false)

  def set(shader, name, value, use_shader) when is_float(value) do
    if use_shader, do: use_shader(shader)

    :gl.uniform1f(:gl.getUniformLocation(shader, name), value)

    shader
  end

  def set(shader, name, value, use_shader) when is_integer(value) do
    if use_shader, do: use_shader(shader)

    :gl.uniform1i(:gl.getUniformLocation(shader, name), value)

    shader
  end

  def set(shader, name, true, use_shader), do: set(shader, name, 1, use_shader)

  def set(shader, name, false, use_shader), do: set(shader, name, 0, use_shader)

  def set(shader, name, {x, y}, use_shader) do
    if use_shader, do: use_shader(shader)

    :gl.uniform2f(:gl.getUniformLocation(shader, name), x, y)

    shader
  end

  def set(shader, name, {x, y, z}, use_shader) do
    if use_shader, do: use_shader(shader)

    :gl.uniform3f(:gl.getUniformLocation(shader, name), x, y, z)

    shader
  end

  def set(shader, name, {x, y, z, w}, use_shader) do
    if use_shader, do: use_shader(shader)

    :gl.uniform4f(:gl.getUniformLocation(shader, name), x, y, z, w)

    shader
  end

  def set(shader, name, value, use_shader)
      when is_list(value) and tuple_size(value |> hd()) == 16 do
    if use_shader, do: use_shader(shader)

    :gl.uniformMatrix4fv(:gl.getUniformLocation(shader, name), :gl_const.gl_false(), value)

    shader
  end

  def set(shader, name, value, use_shader)
      when is_list(value) and tuple_size(value |> hd()) == 2 do
    if use_shader, do: use_shader(shader)

    :gl.uniform2fv(:gl.getUniformLocation(shader, name), value)
  end

  def set(shader, name, value, use_shader) when is_list(value) and is_integer(value |> hd()) do
    if use_shader, do: use_shader(shader)

    :gl.uniform1iv(:gl.getUniformLocation(shader, name), value)
  end

  def set(shader, name, value, use_shader) when is_list(value) and is_float(value |> hd()) do
    if use_shader, do: use_shader(shader)

    :gl.uniform1fv(:gl.getUniformLocation(shader, name), value)
  end
end
