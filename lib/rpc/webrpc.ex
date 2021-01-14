defmodule Sonnam.WebRpc do
  @moduledoc """
  rpc via http
  """

  def execute(service_addr, service_name, call, args, extra) do
    with url <- "#{service_addr}/#{service_name}/#{call}",
         headers <- [
           {"connection", "keep-alive"},
           {"content-type", "application/json"},
           {"current-uid", Keyword.get(extra, :uid, "NA")},
           {"x-request-id", Keyword.get(extra, :"x-request-id", "")}
         ],
         {:ok, encoded_args} <- Jason.encode(args),
         timeout <- Keyword.get(extra, :timeout, 2000),
         {:ok, response} <-
           HTTPoison.post(
             url,
             encoded_args,
             headers,
             recv_timeout: timeout
           ) do
      process(response)
    else
      _ ->
        {:error, "Internal server error"}
    end
  end

  defp process(%HTTPoison.Response{body: body, status_code: 200}) do
    body
    |> Jason.decode()
    |> (fn
          {:ok, %{"code" => 200, "data" => data}} -> {:ok, data}
          {:ok, %{"code" => _, "msg" => msg}} -> {:error, msg}
          _ -> {:error, "Internal server error"}
        end).()
  end

  defp process(%HTTPoison.Response{status_code: code}) do
    {:error, "service #{code}"}
  end
end
