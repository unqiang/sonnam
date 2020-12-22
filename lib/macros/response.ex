defmodule Sonnam.Macros.Response do

  defmacro __using__(_opts) do
    quote do
      import Sonnam.Macros.Response
    end
  end


  defmacro reply_succ(conn, data) do
    quote bind_quoted: [conn: conn, data: data] do
      json(conn, %{code: 0, data: data})
    end
  end

  defmacro reply_err(conn, msg, code \\ 500) do
    quote bind_quoted: [conn: conn, msg: msg, code: code] do
      json(conn, %{code: code, data: msg})
      halt(conn)
    end
  end
end
