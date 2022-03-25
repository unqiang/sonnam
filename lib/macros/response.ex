defmodule Sonnam.Macros.Response do
  defmacro __using__(opts) do
    log_resp = Access.get(opts, :log_resp, false)

    quote do
      require Logger
      @log_resp unquote(log_resp)

      def reply_succ(conn, data \\ "success") do
        @log_resp
        |> if do
          Logger.info("succ => #{inspect(data)}")
        end

        json(conn, %{code: 200, data: data})
      end

      def reply_err(conn, msg \\ "internal server error", code \\ 500) do
        Logger.error("failed => #{msg}")

        conn
        |> put_status(500)
        |> json(%{code: code, msg: msg})
      end
    end
  end
end
