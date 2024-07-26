defmodule Breakout.Input do
  require Logger

  import Breakout.WxRecords

  # we can just match on type, but matching on the specific mouse event type
  # (:motion, :left_down, :middle_dclick, etc.) lets us be more specific.
  # we need to connect the callback in Breakout.Window.
  def handler(wx(event: wxMouse(type: :motion, x: _x, y: _y)), state) do
    {:noreply, state}
  end

  def handler(wx(event: wxKey(type: type, x: _x, y: _y, keyCode: key_code)) = _request, state) do
    # IO.inspect(key_code, label: type)
    # send(Breakout.Game, {type, key_code})
    :wx_object.cast(Breakout.Game, {type, key_code})

    {:noreply, state}
  end

  def handler(request, state) do
    Logger.debug(request: request, state: state)

    {:noreply, state}
  end
end
