defmodule Breakout.Game do
  require Logger

  import Breakout.WxRecords

  alias Breakout.State
  alias Breakout.PowerUp
  alias Breakout.Renderer.PostProcessor
  alias Breakout.ParticleGenerator
  alias Breakout.{BallObject, GameObject, GameLevel}
  alias Breakout.Renderer
  alias Renderer.{Texture2D, Sprite, Shader, Window, OpenGL}
  alias Breakout.Math
  alias Math.{Vec2, Vec3, Mat4}
  alias Breakout.Audio.SoundEffect

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

    font = :wxFont.new(32, :wx_const.wx_fontfamily_teletype, :wx_const.wx_fontstyle_normal, :wx_const.wx_fontweight_normal)
    brush = :wxBrush.new({0, 0, 0})

    state = %State{
      t: :erlang.monotonic_time(:millisecond),
      start: :erlang.monotonic_time(),
      dt: 1,
      window: window,
      width: @screen_width,
      height: @screen_height,
      power_ups: [],
      ball: BallObject.new(),
      font: font,
      brush: brush,
    }

    menu_text = """
    press enter to start
press w or s to select level
"""

    menu_font = :wxFont.new(60, :wx_const.wx_fontfamily_teletype, :wx_const.wx_fontstyle_normal, :wx_const.wx_fontweight_bold)

    {menu_string_texture, menu_string_w, menu_string_h} = load_texture_by_string(menu_font, brush, {222, 222, 222}, menu_text, false)

    state = put_in(state.menu_string_size, {menu_string_w, menu_string_h})

    state = put_in(state.resources.textures[:menu_string], menu_string_texture)

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

    state = %Breakout.State{state | sprite_renderer: sprite_renderer}

    state =
      put_in(
        state.resources.textures[:face],
        Texture2D.load("priv/textures/awesomeface.png", true)
      )

    state = put_in(state.resources.textures[:ascii],
      Texture2D.load("priv/textures/ascii_rgb.png", false)
    )

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

    pp_shader =
      Shader.init(
        "priv/shaders/post_processor/vertex.vs",
        "priv/shaders/post_processor/fragment.fs"
      )

    {scaled_width, scaled_height} =
      Vec2.new(@screen_width, @screen_height)
      |> Vec2.scale(:wxWindow.getDPIScaleFactor(window.frame))

    post_processor = PostProcessor.new(pp_shader, trunc(scaled_width), trunc(scaled_height))

    state = %Breakout.State{state | post_processor: post_processor}

    send(self(), :loop)

    {window.frame, state}
  end

  @spec do_collisions(State.t()) :: State.t()
  def do_collisions(%State{} = state) do
    cur_level = state.levels |> elem(state.level)

    {updated_bricks, new_state} =
      Enum.map_reduce(cur_level.bricks, state, fn %GameObject{} = box, acc ->
        unless box.destroyed do
          {collided, dir, diff} = GameObject.check_collision(acc.ball, box)

          if collided do
            {box, new_state} =
              if not box.is_solid do
                new_box = %GameObject{box | destroyed: true}
                new_state = spawn_power_ups(acc, new_box)
                SoundEffect.play(:block)

                {new_box, new_state}
              else
                new_state = %State{
                  acc
                  | shake_time: 0.05,
                    post_processor: %PostProcessor{acc.post_processor | shake: true}
                }
                SoundEffect.play(:solid)

                {box, new_state}
              end

            # TODO: this allows passing through solid blocks, which is kinda weird.
            updated_ball =
              unless new_state.ball.passthrough do
                resolve_collision(new_state.ball, dir, diff)
              else
                new_state.ball
              end

            new_state = %State{new_state | ball: updated_ball}
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
            SoundEffect.play(:powerup)
            put_in(acc.power_ups, power_ups)
          else
            power_ups = List.update_at(acc.power_ups, index, fn _ -> power_up end)
            put_in(acc.power_ups, power_ups)
          end
        else
          acc
        end
      end)

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

        SoundEffect.play(:paddle)

        put_in(ball.stuck, ball.sticky)
      else
        new_state.ball
      end

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
    state = %{state | keys_processed: MapSet.delete(state.keys_processed, key_code)}

    {:noreply, state}
  end

  @impl :wx_object
  def handle_cast(request, state) do
    IO.inspect(request, label: "handle_cast")
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
  def handle_info(:loop, %State{} = state) do
    t = :erlang.monotonic_time(:millisecond)
    dt = t - state.t
    now = :erlang.monotonic_time()
    elapsed = now - state.start
    state = put_in(state.elapsed, elapsed / :erlang.convert_time_unit(1, :second, :native))

    send(self(), {:update, dt})
    send(self(), {:process_input, dt})
    send(self(), :render)
    send(self(), :loop)

    {:noreply, %State{state | t: t, dt: dt}}
  end

  @impl :wx_object
  def handle_info({:update, dt}, %State{} = state) do
    ball = BallObject.move(state.ball, dt, @screen_width)

    state = put_in(state.ball, ball)

    state = do_collisions(state)

    {_, ball_y} = state.ball.game_object.position

    state =
      if ball_y >= @screen_height do
        state = update_in(state.lives, &(&1 - 1))
        if state.lives == 0 do
          state = state
            |> reset_level()
          put_in(state.game_state, :menu)
        else
          state
        end
        |> reset_player()
        |> reset_ball()
      else
        state
      end

    state = update_power_ups(state, dt)

    pg =
      ParticleGenerator.update(
        state.particle_generator,
        dt,
        state.ball.game_object,
        2,
        Vec2.new(state.ball.radius / 2.0, state.ball.radius / 2.0)
      )

    state = put_in(state.particle_generator, pg)

    {shake_time, pp} =
      if state.shake_time > 0 do
        st = state.shake_time - 0.005

        pp =
          if st <= 0 do
            %PostProcessor{state.post_processor | shake: false}
          else
            state.post_processor
          end

        {st, pp}
      else
        {state.shake_time, state.post_processor}
      end

      # t = :erlang.system_time() / 1_000_000_000
      # r = 127.5 * (1 + :math.sin(t))
      # g = 127.5 * (1 + :math.sin(t + 2 * :math.pi / 3))
      # b = 127.5 * (1 + :math.sin(t + 4 * :math.pi / 3))

      state = put_in(state.resources.textures[:string], load_texture_by_string(state.font, state.brush, {222, 222, 222}, "Lives: #{state.lives}", false) |> elem(0))

    {:noreply, %State{state | shake_time: shake_time, post_processor: pp}}
  end

  @impl :wx_object
  def handle_info({:process_input, dt}, state) do
    state = if state.game_state == :menu do
      state = if MapSet.member?(state.keys, 13) and not MapSet.member?(state.keys_processed, 13) do
        state = put_in(state.game_state, :active)
        put_in(state.keys_processed, MapSet.put(state.keys_processed, 13))
      else
        state
      end
      state = if MapSet.member?(state.keys, ?W) and not MapSet.member?(state.keys_processed, ?W) do
        state = update_in(state.level, &(rem(&1 + 1, tuple_size(state.levels))))
        put_in(state.keys_processed, MapSet.put(state.keys_processed, ?W))
      else
        state
      end
      if MapSet.member?(state.keys, ?S) and not MapSet.member?(state.keys_processed, ?S) do
        state = if state.level > 0 do
          update_in(state.level, &(&1 - 1))
        else
          put_in(state.level, 3)
        end
        put_in(state.keys_processed, MapSet.put(state.keys_processed, ?S))
      else
        state
      end
    else
      state
    end

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
                  state.ball
                  | game_object: b.game_object,
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
                  state.ball
                  | game_object: b.game_object,
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
      else
        state
      end

    state =
      if MapSet.member?(state.keys, ~c" " |> hd) do
        %Breakout.State{
          state
          | ball: %BallObject{
              state.ball
              | game_object: state.ball.game_object,
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

      if state.game_state in [:active, :menu] do
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
        PostProcessor.render(state.post_processor, state.elapsed)

        Sprite.draw(
          state,
          :string,
          Vec2.new(10, 0),
          Vec2.new(200, 100),
          0,
          Vec3.new(1, 1, 1)
        )
      end

      if state.game_state == :menu do
        {w, h} = state.menu_string_size
        Sprite.draw(
          state,
          :menu_string,
          # TODO: either I'm very tired, or this is.. weird.
          Vec2.new((state.width - w / 2) / 2, state.height / 2 - h),
          state.menu_string_size,
          0,
          Vec3.new(1, 1, 1)
        )
      end

      :wxGLCanvas.swapBuffers(state.window.canvas)
    end)

    {:noreply, state}
  end

  @impl :wx_object
  def handle_info(info, state) do
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

    state = put_in(state.levels, levels)
    put_in(state.lives, 3)
  end

  defp level_name(0), do: "one.lvl"
  defp level_name(1), do: "two.lvl"
  defp level_name(2), do: "three.lvl"
  defp level_name(3), do: "four.lvl"

  defp reset_player(%State{} = state) do
    player = %{state.player | position: @player_position, size: Vec2.new(100, 20)}

    put_in(state.player, player)
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

    put_in(state.ball, ball)
  end

  defp should_spawn(chance) do
    :rand.uniform(chance) == chance
  end

  @spec spawn_power_ups(state :: Breakout.State.t(), block :: GameObject.t()) ::
          Breakout.State.t()
  defp spawn_power_ups(state, block) do
    state
    |> maybe_spawn_power_up(:chaos, Vec3.new(0.9, 0.25, 0.25), 15, block, :chaos, 10)
    |> maybe_spawn_power_up(:confuse, Vec3.new(1, 0.3, 0.3), 15, block, :confuse, 10)
    |> maybe_spawn_power_up(:increase, Vec3.new(1, 0.6, 0.4), 10, block, :increase, 10)
    |> maybe_spawn_power_up(:passthrough, Vec3.new(0.5, 1, 0.5), 10, block, :passthrough, 10)
    |> maybe_spawn_power_up(:speed, Vec3.new(0.5, 0.5, 1), 10, block, :speed, 10)
    |> maybe_spawn_power_up(:sticky, Vec3.new(1, 0.5, 1), 10, block, :sticky, 10)
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

  @spec activate_power_up(state :: State.t(), power_up :: PowerUp.t()) :: State.t()
  def activate_power_up(%State{} = state, %PowerUp{} = power_up) do
    case power_up.type do
      :speed ->
        update_in(state.ball.game_object.velocity, &Vec2.scale(&1, 1.2))

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
      _ ->
        state
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
          # TODO: subtract some better amount of `dt` instead
          power_up = update_in(power_up.duration, &(&1 - dt / 500.0))

          power_up =
            if power_up.duration <= 0 do
              put_in(power_up.activated, false)
            else
              power_up
            end

          updated = List.update_at(acc.power_ups, index, fn _ -> power_up end)

          acc = put_in(acc.power_ups, updated)

          unless power_up.activated do
            case power_up.type do
              :sticky ->
                unless is_other_power_up_active(acc.power_ups, :sticky) do
                  acc = put_in(acc.ball.sticky, false)
                  put_in(acc.player.color, Vec3.new(1, 1, 1))
                else
                  acc
                end

              :passthrough ->
                unless is_other_power_up_active(acc.power_ups, :passthrough) do
                  acc = put_in(acc.ball.passthrough, false)
                  put_in(acc.ball.game_object.color, Vec3.new(1, 1, 1))
                else
                  acc
                end

              :confuse ->
                unless is_other_power_up_active(acc.power_ups, :confuse) do
                  put_in(acc.post_processor.confuse, false)
                else
                  acc
                end

              :chaos ->
                unless is_other_power_up_active(acc.power_ups, :chaos) do
                  put_in(acc.post_processor.chaos, false)
                else
                  acc
                end

              _ ->
                acc
            end
          else
            acc
          end
        else
          updated = List.update_at(acc.power_ups, index, fn _ -> power_up end)

          put_in(acc.power_ups, updated)
        end
      end)

    update_in(state.power_ups, fn el ->
      Enum.reject(el, fn %PowerUp{game_object: %GameObject{}} = power_up ->
        power_up.game_object.destroyed and not power_up.activated
      end)
    end)
  end

  defp is_other_power_up_active(power_ups, type) do
    power_ups
    |> Enum.any?(&(&1.activated and &1.type == type))
  end

  # This is taken from lib/wx/examples/demo/ex_gl.erl, with the following comment:
  # %% This algorithm (based on http://d0t.dbclan.de/snippets/gltext.html)
  # %% prints a string to a bitmap and loads that onto an opengl texture.
  # %% Comments for the createTexture function:
  # %%
  # %%    "Creates a texture from the settings saved in TextElement, to be
  # %%     able to use normal system fonts conviently a wx.MemoryDC is
  # %%     used to draw on a wx.Bitmap. As wxwidgets device contexts don't
  # %%     support alpha at all it is necessary to apply a little hack to
  # %%     preserve antialiasing without sticking to a fixed background
  # %%     color:
  # %%
  # %%     We draw the bmp in b/w mode so we can use its data as a alpha
  # %%     channel for a solid color bitmap which after GL_ALPHA_TEST and
  # %%     GL_BLEND will show a nicely antialiased text on any surface.
  # %%
  # %%     To access the raw pixel data the bmp gets converted to a
  # %%     wx.Image. Now we just have to merge our foreground color with
  # %%     the alpha data we just created and push it all into a OpenGL
  # %%     texture and we are DONE *inhalesdelpy*"

  defp load_texture_by_string(font, brush, color, string, flip) do
    tmp_bmp = :wxBitmap.new(200, 200)
    tmp = :wxMemoryDC.new(tmp_bmp)
    :wxMemoryDC.setFont(tmp, font)
    {str_w, str_h} = :wxDC.getTextExtent(tmp, string)
    :wxMemoryDC.destroy(tmp)
    :wxBitmap.destroy(tmp_bmp)

    w = get_power_of_two_roof(str_w)
    h = get_power_of_two_roof(str_h)

    bmp = :wxBitmap.new(w, h)
    dc = :wxMemoryDC.new(bmp)
    :wxMemoryDC.setFont(dc, font)
    :wxMemoryDC.setBackground(dc, brush)
    :wxMemoryDC.clear(dc)
    :wxMemoryDC.setTextForeground(dc, {255, 255, 255})
    :wxMemoryDC.drawText(dc, string, {0, 0})

    img_0 = :wxBitmap.convertToImage(bmp)
    img = case flip do
      true ->
        img = :wxImage.mirror(img_0, horizontally: false)
        :wxImage.destroy(img_0)
        img
      false ->
        img_0
    end

    alpha = :wxImage.getData(img)
    data = colourize_image(alpha, color)
    :wxImage.destroy(img)
    :wxBitmap.destroy(bmp)
    :wxMemoryDC.destroy(dc)

    [tid] = :gl.genTextures(1)
    :gl.bindTexture(:gl_const.gl_texture_2d, tid)
    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texture_mag_filter, :gl_const.gl_linear)
    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texture_min_filter, :gl_const.gl_linear)
    :gl.texEnvi(:gl_const.gl_texture_env, :gl_const.gl_texture_env_mode, :gl_const.gl_replace)
    :gl.texImage2D(:gl_const.gl_texture_2d, 0, :gl_const.gl_rgba, w, h, 0, :gl_const.gl_rgba, :gl_const.gl_unsigned_byte, data)

    {%Texture2D{
      id: tid,
      width: w,
      height: h,
      internal_format: :gl_const.gl_rgba,
      image_format: :gl_const.gl_rgba,
      wrap_s: :gl_const.gl_repeat,
      wrap_t: :gl_const.gl_repeat,
      filter_min: :gl_const.gl_linear,
      filter_max: :gl_const.gl_linear
    }, str_w, str_h}
  end

  defp colourize_image(alpha, {r, g, b}) do
    for <<a::8, _::8, _::8 <- alpha>>, into: <<>> do
      <<r::8, g::8, b::8, a::8>>
    end
  end

  defp get_power_of_two_roof(x), do: get_power_of_two_roof_2(1, x)
  defp get_power_of_two_roof_2(n, x) when n >= x, do: n
  defp get_power_of_two_roof_2(n, x), do: get_power_of_two_roof_2(n * 2, x)
end
