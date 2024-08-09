# This is taken from one of the Membrane maintainers (Mateusz Front, I believe).
# slight modification to make it loop infinitely.
defmodule Breakout.Audio.LoopFilter do
  use Membrane.Filter

  def_input_pad :input, accepted_format: _any
  def_output_pad :output, accepted_format: _any

  def_options loops: [spec: integer() | :infinity]

  @impl true
  def handle_init(_ctx, opts) do
    {[], %{loops: opts.loops}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    seek(state)
  end

  @impl true
  def handle_event(:input, %Membrane.File.EndOfSeekEvent{}, _ctx, state) do
    seek(state)
  end

  @impl true
  def handle_event(pad, event, ctx, state) do
    super(pad, event, ctx, state)
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    {[buffer: {:output, buffer}], state}
  end

  defp seek(state) do
    %{loops: loops} = state

    event = case loops do
      :infinity ->
        %Membrane.File.SeekSourceEvent{start: :bof, size_to_read: :infinity}

      1 ->
        %Membrane.File.SeekSourceEvent{start: :bof, size_to_read: :infinity, last?: true}

      _ -> nil
    end

    actions = if event, do: [event: {:input, event}], else: []
    state = unless state.loops == :infinity do
      update_in(state.loops, &(&1 - 1))
    else
      state
    end

    {actions, state}
  end
end

defmodule Breakout.Audio do
  use Membrane.Pipeline

  def start_link(args) do
    Membrane.Pipeline.start_link(__MODULE__, args, name: __MODULE__)
  end

  # This is taken from membraneframework/membrane_demo/simple_pipeline

  @impl Membrane.Pipeline
  def handle_init(_ctx, path_to_mp3) do
    spec =
      child(:file, %Membrane.File.Source{location: path_to_mp3, seekable?: true})
      |> child(:decoder, Membrane.MP3.MAD.Decoder)
      |> child(:converter, %Membrane.FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 44_100,
          channels: 2,
        }
      })
      |> child(%Breakout.Audio.LoopFilter{loops: :infinity})
      |> child(:portaudio, Membrane.PortAudio.Sink)

      {[spec: spec], %{}}
  end

  @impl Membrane.Pipeline
  def handle_element_end_of_stream(:sink, :input, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl Membrane.Pipeline
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end

  # @impl Membrane.Pipeline
  # def handle_element_end_of_stream(child, pad, context, state) do
  #   Membrane.Pipeline.terminate(__MODULE__)
  # end
end

defmodule Breakout.Audio.SoundEffect do
  use Membrane.Pipeline

  def play(which) do
    case which do
      :block ->
        {:ok, _sup, _pipe} =
          Membrane.Pipeline.start(__MODULE__, "priv/audio/block.mp3")
      :solid ->
        {:ok, _sup, _pipe} =
          Membrane.Pipeline.start(__MODULE__, "priv/audio/solid.mp3")
      :paddle ->
        {:ok, _sup, _pipe} =
          Membrane.Pipeline.start(__MODULE__, "priv/audio/paddle.mp3")
      :powerup ->
        {:ok, _sup, _pipe} =
          Membrane.Pipeline.start(__MODULE__, "priv/audio/powerup.mp3")
      _ -> nil
      end
  end

  def start(args) do
    Membrane.Pipeline.start(__MODULE__, args, name: __MODULE__)
  end

  # This is taken from membraneframework/membrane_demo/simple_pipeline

  @impl Membrane.Pipeline
  def handle_init(_ctx, path_to_mp3) do
    spec =
      child(:file, %Membrane.File.Source{location: path_to_mp3})
      |> child(:decoder, Membrane.MP3.MAD.Decoder)
      |> child(:converter, %Membrane.FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 48_000,
          channels: 2,
        }
      })
      # |> child(%Breakout.Audio.LoopFilter{loops: :infinity})
      |> child(:portaudio, Membrane.PortAudio.Sink)

      {[spec: spec], %{}}
  end

  @impl Membrane.Pipeline
  def handle_element_end_of_stream(:sink, :input, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl Membrane.Pipeline
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end
