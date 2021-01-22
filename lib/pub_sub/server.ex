defmodule Sonnam.PubSub.Server do
  @moduledoc """
  task subscriber base on redis
  """

  use Supervisor
  require Logger

  @type sub_opts :: [
          queue: String.t(),
          handler: atom(),

          # for redis
          name: atom(),
          host: String.t(),
          port: integer(),
          password: String.t()
        ]
  @timeout 3

  @spec start_link(sub_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    name = Keyword.get(args, :name, :sub)
    {queue, args} = Keyword.pop(args, :queue)
    {handler, args} = Keyword.pop(args, :handler)

    children = [
      {Redix, args},
      {Task, fn -> loop(name, queue, handler) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def loop(name, queue, handler) do
    Logger.debug("#{queue} subscriber beat!")

    name
    |> Redix.command(["BRPOP", queue, to_string(@timeout)])
    |> (fn
          {:ok, [_, event]} ->
            Task.start(fn -> process_event(handler, event) end)
            loop(name, queue, handler)

          {:error, _} ->
            Process.sleep(@timeout * 1000)
            loop(name, queue, handler)

          _ ->
            Process.sleep(@timeout * 1000)
            loop(name, queue, handler)
        end).()
  end

  defp process_event(handler, event) do
    Logger.info("recv event => #{event}")

    event
    |> Jason.decode()
    |> (fn
          {:ok, %{"call" => call, "body" => body}} ->
            apply(handler, String.to_atom(call), [body])

          {:ok, %{"call" => call}} ->
            apply(handler, String.to_atom(call), [])

          other ->
            Logger.error("invalid event => #{inspect(other)}")
        end).()
  end
end
