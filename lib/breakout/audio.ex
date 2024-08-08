defmodule Breakout.Audio do
  use Membrane.Pipeline

  def start_link(args) do
    Membrane.Pipeline.start_link(__MODULE__, args, name: __MODULE__)
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
          sample_rate: 44_100,
          channels: 2,
        }
      })
      |> child(:portaudio, Membrane.PortAudio.Sink)

      {[spec: spec], %{}}
  end

  @impl Membrane.Pipeline
  def handle_element_end_of_stream(child, pad, context, state) do
    Membrane.Pipeline.terminate(__MODULE__)
  end
end
