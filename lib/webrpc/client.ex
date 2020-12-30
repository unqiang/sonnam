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

  @spec async_execute(atom(), String.t(), keyword(), keyword()) :: :ok
  def async_execute(pid, call, args, extra \\ []),
    do: GenServer.cast(pid, {:call, call, args, extra})

  def init(base_url: url, service: service) do
    {:ok, %{base_url: url, service: service}}
  end

  def handle_call({:call, call, args, extra}, _, state),
    do: {:reply, _call("#{state.base_url}/#{state.service}/#{call}", args, extra), state}

  def handle_cast({:call, call, args, extra}, state) do
    _call("#{state.base_url}/#{state.service}/#{call}", args, extra)
    {:noreply, state}
  end

  defp _call(url, args, extra) do
    with headers <- [
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
          {:ok, %{"code" => 0, "data" => data}} -> {:ok, data}
          {:ok, %{"code" => _, "data" => data}} -> {:error, data}
          _ -> {:error, "Internal server error"}
        end).()
  end

  defp process(%HTTPoison.Response{status_code: code}) do
    {:error, "service #{code}"}
  end
end
