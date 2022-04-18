defmodule Sonnam.Macros.Response do
  defmacro __using__(_opts) do
    quote do
      require Logger

      def reply_succ(conn, data \\ "success") do
        Logger.debug("succ => #{inspect(data)}")

        json(conn, %{code: 200, data: data})
      end

      def reply_err(conn, msg \\ "Internal server error", code \\ 400)

      def reply_err(conn, msg, code) do
        Logger.error("failed; code=>#{code}, => #{msg}")

        json(conn, %{code: code, msg: msg})
      end
    end
  end
end
