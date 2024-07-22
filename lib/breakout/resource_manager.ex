defmodule Breakout.ResourceManager do
  use GenServer

  require Logger

  alias Breakout.Renderer.{Shader, Texture2D}

  defstruct shaders: %{}, textures: %{}

  @type t :: %__MODULE__{
          shaders: %{atom() => Shader.t()},
          textures: %{atom() => Texture2D.t()}
        }

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, new()}
  end

  def new() do
    %__MODULE__{}
  end

  @impl GenServer
  def handle_cast({:put_shader, name, shader}, state) do
    state = put_in(state.shaders[name], shader)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:put_texture, name, texture}, state) do
    state = put_in(state.textures[name], texture)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_shader, name}, _from, state) do
    reply = Map.get(state.shaders, name)

    {:reply, {:ok, reply}, state}
  end

  @impl GenServer
  def handle_call({:get_texture, name}, _from, state) do
    reply = Map.get(state.textures, name)

    {:reply, {:ok, reply}, state}
  end

  def put_shader(shader, name) do
    GenServer.cast(__MODULE__, {:put_shader, name, shader})

    shader
  end

  def get_shader(name) do
    GenServer.call(__MODULE__, {:get_shader, name})
  end

  def put_texture(texture, name) do
    GenServer.cast(__MODULE__, {:put_texture, name, texture})

    texture
  end

  def get_texture(name) do
    GenServer.call(__MODULE__, {:get_texture, name})
  end
end
