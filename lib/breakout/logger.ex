defmodule Breakout.Logger do
  def format(level, message, {_date, time} = _timestamp, metadata) do
    # \t#{inspect(metadata)}\n"
    msg = "\n[#{level}] #{Logger.Formatter.format_time(time)}: #{message}\n\t"

    meta =
      for {k, v} <- metadata do
        "#{inspect(k)}, #{inspect(v)}"
      end
      |> Enum.join("\n\t")

    msg <> meta <> "\n"
  end
end
