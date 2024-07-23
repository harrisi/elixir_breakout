defmodule Breakout.Game do
  require Logger

  import Breakout.WxRecords

  alias Breakout.ParticleGenerator
  alias Breakout.{BallObject, GameObject, GameLevel}
  alias Breakout.Renderer
  alias Renderer.{Texture2D, Sprite, Shader, Window, OpenGL}
  alias Breakout.Math
  alias Math.{Vec2, Vec3, Mat4}

  @behaviour :wx_object

  @screen_width 1200
  @screen_height 800

  @initial_ball_velocity_x -0.25
  @initial_ball_velocity_y -0.25
  @initial_ball_velocity {@initial_ball_velocity_x, @initial_ball_velocity_y}

  @ball_radius 12.5

  @player_size_x @screen_width / 2 - 50
  @player_size_y @screen_height - 60
  @player_size {@player_size_x, @player_size_y}

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      significant: true,
      restart: :temporary
    }
  end

  @impl :wx_object
  def init(_arg) do
    window = Window.init(@screen_width, @screen_height)

    OpenGL.init()

    # Process.send_after(self(), :loop, 10)

    state = %Breakout.State{
      t: :erlang.monotonic_time(:millisecond),
      dt: 1,
      window: window,
      width: @screen_width,
      height: @screen_height
    }

    projection = Mat4.ortho(0.0, state.width + 0.0, state.height + 0.0, 0.0, -1.0, 1.0)

    sprite_shader =
      Shader.init("priv/shaders/vertex.vs", "priv/shaders/fragment.fs")
      |> Shader.use_shader()
      |> Shader.set(~c"image", 0)
      |> Shader.set(~c"projection", projection |> Mat4.flatten())

    # |> ResourceManager.put_shader(:sprite)
    # state = %Breakout.State{state | resources}
    state = put_in(state.resources.shaders[:sprite], sprite_shader)
    sprite_renderer = Sprite.new(sprite_shader)

    particle_shader =
      Shader.init("priv/shaders/particle/vertex.vs", "priv/shaders/particle/fragment.fs")
    |> Shader.set(~c"projection", projection |> Mat4.flatten(), true)

    state = put_in(state.resources.shaders[:particle], particle_shader)
    state =
      put_in(
        state.resources.textures[:particle],
        Texture2D.load("priv/textures/particle.png", true)
      )

    state = %{
      state
      | particle_generator:
          ParticleGenerator.new(
            particle_shader,
            state.resources.textures[:particle],
            500
          )
    }
      IO.inspect("just made new generator")

    state = %Breakout.State{state | sprite_renderer: sprite_renderer}

    state =
      put_in(
        state.resources.textures[:face],
        Texture2D.load("priv/textures/awesomeface.png", true)
      )

    # |> IO.inspect(label: "face")
    # |> ResourceManager.put_texture(:face)

    state =
      put_in(
        state.resources.textures[:background],
        Texture2D.load("priv/textures/background.png", false)
      )

    # |> ResourceManager.put_texture(:background)

    state =
      put_in(state.resources.textures[:block], Texture2D.load("priv/textures/block.png", false))

    # |> ResourceManager.put_texture(:block)

    state =
      put_in(
        state.resources.textures[:block_solid],
        Texture2D.load("priv/textures/block_solid.png", false)
      )

    # |> ResourceManager.put_texture(:block_solid)

    state = %Breakout.State{
      state
      | levels: {
          GameLevel.load("priv/levels/one.lvl", @screen_width, @screen_height / 2),
          GameLevel.load("priv/levels/two.lvl", @screen_width, @screen_height / 2),
          GameLevel.load("priv/levels/three.lvl", @screen_width, @screen_height / 2),
          GameLevel.load("priv/levels/four.lvl", @screen_width, @screen_height / 2)
        },
        level: 0
    }

    state =
      put_in(state.resources.textures[:paddle], Texture2D.load("priv/textures/paddle.png", true))

    # |> ResourceManager.put_texture(:paddle)

    # {:ok, player_texture} = ResourceManager.get_texture(:paddle)
    player_texture = state.resources.textures[:paddle]

    player =
      GameObject.new(
        @player_size,
        Vec2.new(100, 20),
        player_texture,
        Vec3.new(1, 1, 1),
        500.0
      )

    state = %Breakout.State{state | player: player}

    ball_pos =
      player.position
      |> Vec2.add(Vec2.new(@player_size_x / 2 - @ball_radius - 225, -@ball_radius * 2))

    # {:ok, ball_tex} = ResourceManager.get_texture(:face)
    ball_tex = state.resources.textures[:face]
    ball = BallObject.new(ball_pos, @ball_radius, @initial_ball_velocity, ball_tex)

    state = %Breakout.State{state | ball: ball}

    # {:ok, background} = ResourceManager.get_texture(:background)
    background = state.resources.textures[:background]

    state = %Breakout.State{state | background_texture: background}
    send(self(), :loop)

    {window.frame, state}
  end

  def do_collisions(state) do
    cur_level = state.levels |> elem(state.level)
    ball = state.ball

    {updated_bricks, ball} =
      Enum.map_reduce(cur_level.bricks, ball, fn box, ball_acc ->
        unless box.destroyed do
          {collided, dir, diff} = GameObject.check_collision(ball_acc, box)

          if collided do
            box =
              unless box.is_solid do
                %{box | destroyed: true}
              else
                box
              end

            updated_ball = resolve_collision(ball_acc, dir, diff)
            {box, updated_ball}
          else
            {box, ball_acc}
          end
        else
          {box, ball_acc}
        end
      end)

    level = %{cur_level | bricks: updated_bricks}

    {paddle_collision, _, _} = GameObject.check_collision(ball, state.player)

    ball =
      if not ball.stuck and paddle_collision do
        {player_x, _player_y} = state.player.position
        {player_w, _player_h} = state.player.size
        {ball_x, _} = ball.game_object.position

        center_board = (player_x + player_w / 2) |> IO.inspect(label: "center_board")
        distance = (ball_x + ball.radius - center_board) |> IO.inspect(label: "distance")
        percentage = (distance / (player_w / 2)) |> IO.inspect(label: "percentage")

        strength = 2
        old_vel = ball.game_object.velocity

        ball = %{
          ball
          | game_object: %{
              ball.game_object
              | velocity:
                  {@initial_ball_velocity_x * percentage * strength, @initial_ball_velocity_y}
            }
        }

        ball = %{
          ball
          | game_object: %{
              ball.game_object
              | velocity:
                  Vec2.normalize(ball.game_object.velocity) |> Vec2.scale(Vec2.length(old_vel))
            }
        }

        {ball_vel_x, ball_vel_y} = ball.game_object.velocity
        %{ball | game_object: %{ball.game_object | velocity: {ball_vel_x, -1 * abs(ball_vel_y)}}}
      else
        ball
      end

    %Breakout.State{state | levels: put_elem(state.levels, state.level, level), ball: ball}
  end

  defp resolve_collision(ball, dir, {diff_x, diff_y}) do
    {ball_vel_x, ball_vel_y} = ball.game_object.velocity
    {ball_pos_x, ball_pos_y} = ball.game_object.position

    case dir do
      :left ->
        ball = %{ball | game_object: %{ball.game_object | velocity: {-ball_vel_x, ball_vel_y}}}
        penetration = ball.radius - abs(diff_x)

        %{
          ball
          | game_object: %{ball.game_object | position: {ball_pos_x + penetration, ball_pos_y}}
        }

      :right ->
        ball = %{ball | game_object: %{ball.game_object | velocity: {-ball_vel_x, ball_vel_y}}}
        penetration = ball.radius - abs(diff_x)

        %{
          ball
          | game_object: %{ball.game_object | position: {ball_pos_x - penetration, ball_pos_y}}
        }

      :up ->
        ball = %{ball | game_object: %{ball.game_object | velocity: {ball_vel_x, -ball_vel_y}}}
        penetration = ball.radius - abs(diff_y)

        %{
          ball
          | game_object: %{ball.game_object | position: {ball_pos_x, ball_pos_y - penetration}}
        }

      :down ->
        ball = %{ball | game_object: %{ball.game_object | velocity: {ball_vel_x, -ball_vel_y}}}
        penetration = ball.radius - abs(diff_y)

        %{
          ball
          | game_object: %{ball.game_object | position: {ball_pos_x, ball_pos_y + penetration}}
        }
    end
  end

  def start do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def start_link(arg) do
    :wx_object.start_link({:local, __MODULE__}, __MODULE__, arg, [])
    {:ok, self()}
  end

  @impl :wx_object
  def terminate(reason, state) do
    Logger.error(msg: reason)
    IO.inspect(reason, label: "terminate")
    Supervisor.stop(Breakout.Supervisor)

    {:shutdown, state}
  end

  @impl :wx_object
  def handle_event(wx(event: wxClose()), state) do
    IO.inspect(state, label: "closing")
    :wxWindow."Destroy"(state.window.frame)

    {:stop, :normal, state}
  end

  @impl :wx_object
  def handle_event(request, state) do
    IO.inspect(request, label: "handle_event")
    {:noreply, state}
  end

  @impl :wx_object
  def handle_call(request, _from, state) do
    IO.inspect(request, label: "handle_call")
    {:noreply, state}
  end

  @impl :wx_object
  def handle_cast({:key_down, key_code}, state) do
    state = %{
      state
      | keys: MapSet.put(state.keys, key_code),
        level:
          if(key_code == ?N,
            do: rem(state.level + 1, tuple_size(state.levels)),
            else: state.level
          )
    }

    if key_code == ?P do
      send(self(), :start_profiling)
    end

    {:noreply, state}
  end

  @impl :wx_object
  def handle_cast({:key_up, key_code}, state) do
    state = %{state | keys: MapSet.delete(state.keys, key_code)}

    {:noreply, state}
  end

  @impl :wx_object
  def handle_cast(request, state) do
    IO.inspect(request, label: "handle_cast")
    IO.inspect("handle_cast")
    {:noreply, state}
  end

  def handle_info(:start_profiling, state) do
    :tprof.start(%{type: :call_time})
    :tprof.enable_trace(:all)
    :tprof.set_pattern(:_, :_, :_)
    # :eprof.start_profiling([self()])
    # :eprof.log(~c'eprof')
    Process.send_after(self(), :stop_profiling, 10_000)
    {:noreply, state}
  end

  def handle_info(:stop_profiling, state) do
    :tprof.disable_trace(:all)
    sample = :tprof.collect()
    inspected = :tprof.inspect(sample, :process, :measurement)
    shell = :maps.get(self(), inspected)

    IO.puts(:tprof.format(shell))

    # :eprof.stop_profiling()
    # :eprof.analyze()
    {:noreply, state}
  end

  @impl :wx_object
  def handle_info(:loop, state) do
    t = :erlang.monotonic_time(:millisecond)
    dt = t - state.t

    # IO.puts("time: #{t}; dt: #{dt}")

    send(self(), {:update, dt})

    send(self(), {:process_input, dt})

    send(self(), :render)

    send(self(), :loop)
    # Process.send_after(self(), :loop, 8)

    {:noreply, %Breakout.State{state | t: t, dt: dt}}
  end

  @impl :wx_object
  def handle_info({:update, dt}, %Breakout.State{} = state) do
    # update game state
    ball = BallObject.move(state.ball, dt, @screen_width)

    state = %Breakout.State{
      state
      | ball: ball
    }

    state = do_collisions(state)

    {_, ball_y} = ball.game_object.position

    state =
      if ball_y >= @screen_height do
        %{
          state
          | levels: reset_level(state),
            player: reset_player(state),
            ball: reset_ball(state)
        }
      else
        state
      end

    pg = ParticleGenerator.update(state.particle_generator, dt, state.ball.game_object, 2, Vec2.new(state.ball.radius / 2.0, state.ball.radius / 2.0))

    state = %Breakout.State{state |
      particle_generator: pg
    }

    {:noreply, state}
  end

  @impl :wx_object
  def handle_info({:process_input, dt}, state) do
    state =
      if state.game_state == :active do
        # _000 #_000
        velocity = state.player.velocity * dt / 1_000

        state =
          if MapSet.member?(state.keys, ?A) do
            {_, new_state} =
              get_and_update_in(state.player.position, fn {x, y} = orig ->
                if x >= 0 do
                  {orig, {x - velocity, y}}
                else
                  {orig, orig}
                end
              end)

            {player_x, _} = state.player.position

            new_ball =
              if player_x >= 0 and state.ball.stuck do
                {ball_x, ball_y} = state.ball.game_object.position

                b =
                  BallObject.new(
                    Vec2.new(ball_x - velocity, ball_y),
                    state.ball.radius,
                    state.ball.game_object.velocity,
                    state.ball.game_object.sprite
                  )

                %BallObject{
                  game_object: b.game_object,
                  stuck: state.ball.stuck,
                  radius: state.ball.radius
                }
              else
                state.ball
              end

            %Breakout.State{new_state | ball: new_ball}
          else
            state
          end

        state =
          if MapSet.member?(state.keys, ?D) do
            {_, new_state} =
              get_and_update_in(state.player.position, fn {x, y} = orig ->
                if x + 100 <= @screen_width do
                  {orig, {x + velocity, y}}
                else
                  {orig, orig}
                end
              end)

            {player_x, _} = state.player.position

            new_ball =
              if player_x + 100 <= @screen_width and state.ball.stuck do
                {ball_x, ball_y} = state.ball.game_object.position

                b =
                  BallObject.new(
                    Vec2.new(ball_x + velocity, ball_y),
                    state.ball.radius,
                    state.ball.game_object.velocity,
                    state.ball.game_object.sprite
                  )

                %BallObject{
                  game_object: b.game_object,
                  stuck: state.ball.stuck,
                  radius: state.ball.radius
                }
              else
                state.ball
              end

            %Breakout.State{new_state | ball: new_ball}
          else
            state
          end

        state
      end

    state =
      if MapSet.member?(state.keys, ~c" " |> hd) do
        %Breakout.State{
          state
          | ball: %BallObject{
              game_object: state.ball.game_object,
              radius: state.ball.radius,
              stuck: false
            }
        }
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:render, %Breakout.State{} = state) do
    :wx.batch(fn ->
      :gl.clearColor(0.0, 0.0, 0.0, 1.0)
      :gl.clear(:gl_const.gl_color_buffer_bit())

      if state.game_state == :active do
        Sprite.draw(
          state,
          :background,
          Vec2.new(0, 0),
          Vec2.new(state.width, state.height),
          0,
          Vec3.new(1, 1, 1)
        )

        level = state.levels |> elem(state.level)
        GameLevel.draw(level, state.sprite_renderer, state)
        GameObject.draw(state.player, :paddle, state.sprite_renderer, state)
        ParticleGenerator.draw(state.particle_generator)
        GameObject.draw(state.ball.game_object, :face, state.sprite_renderer, state)
      end

      :wxGLCanvas.swapBuffers(state.window.canvas)
    end)

    {:noreply, state}
  end

  @impl :wx_object
  def handle_info(info, state) do
    IO.inspect("handle_info")
    Logger.debug(info: info, state: state)

    {:noreply, state}
  end

  defp reset_level(state) do
    res =
      put_elem(
        state.levels,
        state.level,
        GameLevel.load(
          "priv/levels/#{level_name(state.level)}",
          @screen_width,
          @screen_height / 2
        )
      )

    IO.inspect(is_tuple(res))
    res
  end

  defp level_name(0), do: "one.lvl"
  defp level_name(1), do: "two.lvl"
  defp level_name(2), do: "three.lvl"
  defp level_name(3), do: "four.lvl"

  defp reset_player(state) do
    %{state.player | size: @player_size, position: Vec2.new(100, 20)}
  end

  defp reset_ball(state) do
    BallObject.reset(
      state.ball,
      Vec2.add(
        state.player.position,
        Vec2.new(@player_size_x / 2 - @ball_radius - 225, -@ball_radius * 2)
      ),
      @initial_ball_velocity
    )
  end
end
