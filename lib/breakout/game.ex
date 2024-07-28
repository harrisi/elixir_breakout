defmodule Breakout.Game do
  require Logger

  import Breakout.WxRecords

  alias Breakout.Player
  alias Breakout.State
  alias Breakout.PowerUp
  alias Breakout.Renderer.PostProcessor
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

  @player_position_x @screen_width / 2 - 50
  @player_position_y @screen_height - 60
  @player_position {@player_position_x, @player_position_y}

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

    state = %State{
      t: :erlang.monotonic_time(:millisecond),
      start_seconds: :erlang.monotonic_time(),
      dt: 1,
      window: window,
      width: @screen_width,
      height: @screen_height,
      power_ups: [],
      ball: BallObject.new()
    }

    projection = Mat4.ortho(0.0, state.width + 0.0, state.height + 0.0, 0.0, -1.0, 1.0)

    sprite_shader =
      Shader.init("priv/shaders/sprite/vertex.vs", "priv/shaders/sprite/fragment.fs")
      |> Shader.use_shader()
      |> Shader.set(~c"image", 0)
      |> Shader.set(~c"projection", [projection |> Mat4.flatten()])

    # |> ResourceManager.put_shader(:sprite)
    # state = %Breakout.State{state | resources}
    state = put_in(state.resources.shaders[:sprite], sprite_shader)
    sprite_renderer = Sprite.new(sprite_shader)

    particle_shader =
      Shader.init("priv/shaders/particle/vertex.vs", "priv/shaders/particle/fragment.fs")
      |> Shader.set(~c"projection", [projection |> Mat4.flatten()], true)

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

    state =
      put_in(state.resources.textures[:block], Texture2D.load("priv/textures/block.png", false))

    # state = put_in(state.resources.textures[:speed], Texture2D.load("priv/textures/powerup_speed.png", true))
    power_up_textures =
      [
        :chaos,
        :confuse,
        :increase,
        :passthrough,
        :speed,
        :sticky
      ]
      |> Enum.reduce(state.resources.textures, fn el, acc ->
        put_in(acc[el], Texture2D.load("priv/textures/powerup_#{el}.png", true))
      end)

    state = %Breakout.State{
      state
      | resources: %{
          state.resources
          | textures: Map.merge(state.resources.textures, power_up_textures)
        }
    }

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
        @player_position,
        Vec2.new(100, 20),
        player_texture,
        Vec3.new(1, 1, 1),
        500.0
      )

    state = %Breakout.State{state | player: player}

    ball_pos =
      player.position
      |> Vec2.add(Vec2.new(@player_position_x / 2 - @ball_radius, -@ball_radius * 2))

    # {:ok, ball_tex} = ResourceManager.get_texture(:face)
    ball_tex = state.resources.textures[:face]
    ball = BallObject.new(ball_pos, @ball_radius, @initial_ball_velocity, ball_tex)

    state =
      %Breakout.State{state | ball: ball}
      |> reset_ball()

    # {:ok, background} = ResourceManager.get_texture(:background)
    background = state.resources.textures[:background]

    state = %Breakout.State{state | background_texture: background}

    IO.inspect("about to make postprocessor")

    pp_shader =
      Shader.init(
        "priv/shaders/post_processor/vertex.vs",
        "priv/shaders/post_processor/fragment.fs"
      )

    IO.inspect("here?", label: "before new")

    {scaled_width, scaled_height} = Vec2.new(@screen_width, @screen_height)
      |> Vec2.scale(:wxWindow.getDPIScaleFactor(window.frame))

    post_processor = PostProcessor.new(pp_shader, trunc(scaled_width), trunc(scaled_height))

    IO.inspect("here?", label: "after new")

    state = %Breakout.State{state | post_processor: post_processor}

    IO.inspect("made postprocessor")

    send(self(), :loop)

    {window.frame, state}
  end

  @spec do_collisions(State.t()) :: State.t()
  def do_collisions(%State{} = state) do
    cur_level = state.levels |> elem(state.level)

    {updated_bricks, new_state} =
      Enum.map_reduce(cur_level.bricks, state, fn box, acc ->
        # {ball_acc, shake_time_acc, shake_acc, maybe_power_ups_acc} = acc
        unless box.destroyed do
          {collided, dir, diff} = GameObject.check_collision(acc.ball, box)

          if collided do
            {box, new_state} =
              unless box.is_solid do
                new_box = %{box | destroyed: true}
                new_state = spawn_power_ups(acc, new_box)

                # new_state = %{new_state | post_processor: %{new_state.post_processor | shake: true}}
                {new_box, new_state}
              else
                new_state = %{
                  acc
                  | shake_time: 0.05,
                    post_processor: %{acc.post_processor | shake: true}
                }

                {box, new_state}
              end

            updated_ball = resolve_collision(new_state.ball, dir, diff)
            new_state = %{new_state | ball: updated_ball}
            {box, new_state}
          else
            {box, acc}
          end
        else
          {box, acc}
        end
      end)

    level = %{cur_level | bricks: updated_bricks}

    new_state =
      Enum.with_index(new_state.power_ups)
      |> Enum.reduce(new_state, fn {%PowerUp{game_object: %GameObject{}} = power_up, index},
                                   %State{} = acc ->
        unless power_up.game_object.destroyed do
          power_up =
            put_in(
              power_up.game_object.destroyed,
              power_up.game_object.position |> elem(1) >= @screen_height
            )

          if GameObject.check_collision(acc.player, power_up.game_object) do
            acc = activate_power_up(acc, power_up)
            power_up = put_in(power_up.game_object.destroyed, true)
            power_up = put_in(power_up.activated, true)
            power_ups = List.update_at(acc.power_ups, index, fn _ -> power_up end)
            %State{acc | power_ups: power_ups}
          else
            power_ups = List.update_at(acc.power_ups, index, fn _ -> power_up end)
            %State{acc | power_ups: power_ups}
          end
        else
          acc
        end
      end)

    # for %PowerUp{game_object: %GameObject{} = _} = power_up <- state.power_ups do
    #   unless power_up.game_object.destroyed do
    #     power_up = put_in(power_up.game_object.destroyed, (power_up.game_object.position |> elem(1)) >= @screen_height)

    #     if GameObject.check_collision(state.player, power_up.game_object) do
    #       activate_power_up(state, power_up)
    #       destroyed = true
    #       activated = true
    #     else
    #       power_up
    #     end
    #   end
    # end

    {paddle_collision, _, _} = GameObject.check_collision(new_state.ball, state.player)

    ball =
      if not new_state.ball.stuck and paddle_collision do
        {player_x, _player_y} = new_state.player.position
        {player_w, _player_h} = new_state.player.size
        {ball_x, _} = new_state.ball.game_object.position

        center_board = player_x + player_w / 2
        distance = ball_x + new_state.ball.radius - center_board
        percentage = distance / (player_w / 2)

        strength = 2
        old_vel = new_state.ball.game_object.velocity

        ball = %{
          new_state.ball
          | game_object: %{
              new_state.ball.game_object
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
        ball = put_in(ball.game_object.velocity, {ball_vel_x, -1 * abs(ball_vel_y)})
        put_in(ball.stuck, ball.sticky)
      else
        new_state.ball
      end

    # pp = %PostProcessor{
    #   state.post_processor |
    #   shake: new_state.post_processor.shake,
    # }

    # , post_processor: pp}
    %State{new_state | levels: put_elem(state.levels, state.level, level), ball: ball}
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
    seconds = :erlang.monotonic_time()

    # IO.puts("time: #{t}; dt: #{dt}")

    state = %Breakout.State{
      state
      | elapsed_seconds: (seconds - state.start_seconds) / 1_000_000_000.0
    }

    send(self(), {:update, dt})

    send(self(), {:process_input, dt})

    send(self(), :render)

    send(self(), :loop)
    # Process.send_after(self(), :loop, 8)

    {:noreply, %Breakout.State{state | t: t, dt: dt}}
  end

  @impl :wx_object
  def handle_info({:update, dt}, %State{} = state) do
    # update game state
    ball = BallObject.move(state.ball, dt, @screen_width)

    state = %State{
      state
      | ball: ball
    }

    state = do_collisions(state)

    {_, ball_y} = ball.game_object.position

    state =
      if ball_y >= @screen_height do
        state
        |> reset_level()
        |> reset_player()
        |> reset_ball()

        # %{
        #   state
        #   | levels: reset_level(state),
        #     player: reset_player(state),
        #     ball: reset_ball(state)
        # }
      else
        state
      end

    # state = update_in(state.power_ups, fn _ -> update_power_ups(state, dt) end)
    state = update_power_ups(state, dt)

    pg =
      ParticleGenerator.update(
        state.particle_generator,
        dt,
        state.ball.game_object,
        2,
        Vec2.new(state.ball.radius / 2.0, state.ball.radius / 2.0)
      )

    state = %State{state | particle_generator: pg}

    {shake_time, pp} =
      if state.shake_time > 0.0 do
        st = state.shake_time - 0.005

        pp =
          if st <= 0.0 do
            %PostProcessor{state.post_processor | shake: false}
          else
            state.post_processor
          end

        {st, pp}
      else
        {state.shake_time, state.post_processor}
      end

    {:noreply, %State{state | shake_time: shake_time, post_processor: pp}}
  end

  @impl :wx_object
  def handle_info({:process_input, dt}, state) do
    state =
      if state.game_state == :active do
        velocity = state.player.velocity * dt / 1_000

        state =
          if MapSet.member?(state.keys, ?A) or
               MapSet.member?(state.keys, ?H) or
               MapSet.member?(state.keys, 314) do
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
          if MapSet.member?(state.keys, ?D) or
               MapSet.member?(state.keys, ?L) or
               MapSet.member?(state.keys, 316) do
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
        PostProcessor.begin_render(state.post_processor)

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

        Enum.each(state.power_ups, fn %PowerUp{game_object: %GameObject{}} = power_up ->
          unless power_up.game_object.destroyed do
            GameObject.draw(power_up.game_object, power_up.type, state.sprite_renderer, state)
          end
        end)

        PostProcessor.end_render(state.post_processor)
        PostProcessor.render(state.post_processor, state.elapsed_seconds)
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

  defp reset_level(%State{} = state) do
    levels =
      put_elem(
        state.levels,
        state.level,
        GameLevel.load(
          "priv/levels/#{level_name(state.level)}",
          @screen_width,
          @screen_height / 2
        )
      )

    %State{state | levels: levels}
  end

  defp level_name(0), do: "one.lvl"
  defp level_name(1), do: "two.lvl"
  defp level_name(2), do: "three.lvl"
  defp level_name(3), do: "four.lvl"

  defp reset_player(%State{} = state) do
    player = %{state.player | position: @player_position, size: Vec2.new(100, 20)}

    %State{state | player: player}
  end

  defp reset_ball(state) do
    ball =
      BallObject.reset(
        state.ball,
        Vec2.add(
          state.player.position,
          Vec2.new(100 / 2 - @ball_radius, -@ball_radius * 2)
        ),
        @initial_ball_velocity
      )

    %State{state | ball: ball}
  end

  defp should_spawn(chance) do
    :rand.uniform(chance) == chance
  end

  @spec spawn_power_ups(state :: Breakout.State.t(), block :: GameObject.t()) ::
          Breakout.State.t()
  defp spawn_power_ups(state, block) do
    state
    |> maybe_spawn_power_up(:chaos, Vec3.new(0.9, 0.25, 0.25), 15, block, :chaos, 5)
    |> maybe_spawn_power_up(:confuse, Vec3.new(1, 0.3, 0.3), 15, block, :confuse, 5)
    |> maybe_spawn_power_up(:increase, Vec3.new(1, 0.6, 0.4), 0, block, :increase, 5)
    |> maybe_spawn_power_up(:passthrough, Vec3.new(0.5, 1, 0.5), 10, block, :passthrough, 5)
    |> maybe_spawn_power_up(:speed, Vec3.new(0.5, 0.5, 1), 0, block, :speed, 5)
    |> maybe_spawn_power_up(:sticky, Vec3.new(1, 0.5, 1), 20, block, :sticky, 5)
  end

  @spec maybe_spawn_power_up(
          state :: Breakout.State.t(),
          type :: PowerUp.power_up_types(),
          color :: Vec3.t(),
          duration :: number(),
          block :: GameObject.t(),
          texture :: atom(),
          chance :: non_neg_integer()
        ) :: Breakout.State.t()
  defp maybe_spawn_power_up(state, type, color, duration, %GameObject{} = block, texture, chance) do
    if should_spawn(chance) do
      power_up =
        PowerUp.new(
          type,
          color,
          duration + 0.0,
          block.position,
          state.resources.textures[texture]
        )

      Map.update(state, :power_ups, [power_up], &[power_up | &1])
    else
      state
    end
  end

  def activate_power_up(%State{} = state, %PowerUp{} = power_up) do
    case power_up.type do
      :speed ->
        update_in(state.ball.game_object.velocity, &Vec2.scale(&1, 1.2))

      # %State{
      #   state
      #   | ball: %BallObject{state.ball | game_object: %GameObject{velocity: Vec2.scale(state.ball.game_object.velocity, 1.2)}}
      # }
      # |> IO.inspect(label: "state, activate")

      :sticky ->
        %State{
          state
          | ball: %{state.ball | sticky: true},
            player: %{state.player | color: Vec3.new(1, 0.5, 1)}
        }

      :passthrough ->
        %State{
          state
          | ball: %{state.ball | passthrough: true}
        }

      :increase ->
        %State{
          state
          | player: %{
              state.player
              | size: {(state.player.size |> elem(0)) + 50, state.player.size |> elem(1)}
            }
        }

      :confuse ->
        unless state.post_processor.chaos do
          %State{
            state
            | post_processor: %{state.post_processor | confuse: true}
          }
        else
          state
        end

      :chaos ->
        unless state.post_processor.confuse do
          %State{
            state
            | post_processor: %{state.post_processor | chaos: true}
          }
        else
          state
        end
    end
  end

  @spec update_power_ups(state :: State.t(), dt :: float()) :: State.t()
  defp update_power_ups(%State{} = state, dt) do
    state =
      Enum.with_index(state.power_ups)
      |> Enum.reduce(state, fn {%PowerUp{} = power_up, index}, %State{} = acc ->
        power_up =
          power_up.game_object.position
          |> update_in(&Vec2.add(&1, Vec2.scale(power_up.game_object.velocity, dt / 1_000)))

        if power_up.activated do
          power_up = update_in(power_up.duration, &(&1 - dt))

          power_up =
            if power_up.duration <= 0 do
              put_in(power_up.activated, false)
            else
              power_up
            end

          # case power_up.type do
          #   :sticky ->
          #     unless is_other_power_up_active(acc.power_ups, :sticky) do
          #       acc = put_in(acc.ball.sticky, false) |> IO.inspect(label: "put in ball")
          #       put_in(acc.player.color, Vec3.new(1, 1, 1)) |> IO.inspect(label: "put in color")
          #     end
          #   _  -> IO.inspect(power_up.type)
          # end
          # updated = List.update_at(acc.power_ups, index, fn _ -> power_up end)

          acc
        else
          updated = List.update_at(acc.power_ups, index, fn _ -> power_up end)

          %State{
            acc
            | power_ups: updated
          }
        end
      end)

    update_in(state.power_ups, fn el ->
      # IO.inspect(el)
      # Enum.filter(el, &((not &1.game_object.destroyed) or &1.activated))
      Enum.filter(el, fn %PowerUp{game_object: %GameObject{}} = power_up ->
        power_up.activated or not power_up.game_object.destroyed
      end)
    end)

    # for %PowerUp{game_object: %GameObject{}} = power_up <- state.power_ups do
    #   power_up =
    #     power_up.game_object.position
    #     |> update_in(&(Vec2.add(&1, Vec2.scale(power_up.game_object.velocity, dt / 1_000))))

    #   _power_up =
    #     if power_up.activated do
    #       _power_up = update_in(power_up.duration, &(&1 - dt))
    #       # case power_up.type do
    #       #   :sticky ->
    #       #     unless is_other_power_up_active(state.power_ups, :sticky) do

    #       #     end
    #       # end
    #     else
    #       power_up
    #     end
    # end
  end

  def is_other_power_up_active(power_ups, type) do
    Enum.any?(power_ups, &(&1.type == type))
  end
end
