defmodule Sonnam.Macros.Response do

  require Logger

  defmacro reply_succ(conn, data \\ "success") do
    quote bind_quoted: [conn: conn, data: data] do
      Logger.info("reply succ => #{inspect(data)}")
      json(conn, %{code: 200, data: data})
    end
  end

  defmacro reply_err(conn, msg \\ "Internal server error", code \\ 500) do
    quote bind_quoted: [conn: conn, msg: msg, code: code] do
      Logger.error("reply err => #{inspect(msg)}")
      json(conn, %{code: code, msg: msg})
    end
  end
end
