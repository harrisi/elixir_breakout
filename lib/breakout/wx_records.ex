defmodule Breakout.WxRecords do
  require Record

  for {type, record} <- Record.extract_all(from_lib: "wx/include/wx.hrl") do
    Record.defrecord(type, record)
  end
end
