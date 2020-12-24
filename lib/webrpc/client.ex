defmodule Sonnam.Webrpc.Client do
  @moduledoc """
  remote call process with microservices
  """
  use GenServer
  require Logger

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec execute(atom(), String.t(), keyword(), keyword()) ::
          {:ok, any()} | {:error, String.t()}
  def execute(pid, call, args, extra \\ []),
    do: GenServer.call(pid, {:call, call, args, extra})

  def init(base_url: url, service: service) do
    {:ok, %{base_url: url, service: service}}
  end

  def handle_call({:call, call, args, extra}, _, state) do
    with headers <- [
           {"User-Agent", "icewine"},
           {"Connection", "keep-alive"},
           {"Content-Type", "application/json"},
           {"Current-Uid", Keyword.get(extra, :uid, "NA")},
           {"Request-From", Keyword.get(extra, :request_from, "NA")}
         ],
         {:ok, encoded_args} <- Jason.encode(args),
         timeout <- Keyword.get(extra, :timeout, 2000),
         {:ok, response} <-
           HTTPoison.post(
             "#{state.base_url}/#{state.service}/#{call}",
             encoded_args,
             headers,
             recv_timeout: timeout
           ) do
      {:reply, process(response), state}
    else
      err -> {:reply, {:error, inspect(err)}, state}
    end
  end

  defp process(%HTTPoison.Response{body: body, status_code: 200}) do
    body
    |> Jason.decode!()
    |> (fn
          %{"code" => 0, "data" => data} -> {:ok, data}
          %{"code" => _, "data" => data} -> {:error, data}
        end).()
  end

  defp process(%HTTPoison.Response{status_code: code}) do
    {:error, "service #{code}"}
  end
end
