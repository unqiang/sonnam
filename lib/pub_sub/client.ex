defmodule Sonnam.PubSub.Client do
  @moduledoc """
  task publish base on redis
  """

  use Supervisor

  @type pub_opts :: [
          name: atom(),
          host: String.t(),
          port: integer(),
          password: String.t()
        ]

  @type event :: {String.t(), String.t()}

  @spec start_link(pub_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    children = [
      {Redix, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec pub_to(atom(), event(), map() | String.t()) :: {:ok, integer()}
  def pub_to(name, event, body) do
    with {queue, call} <- event,
         {:ok, msg} <- Jason.encode(%{"call" => call, "body" => body}) do
      Redix.command(name, ["LPUSH", queue, msg])
    end
  end

  @spec pub_to(atom(), event()) :: {:ok, integer()}
  def pub_to(name, event) do
    with {queue, call} <- event,
         {:ok, msg} <- Jason.encode(%{"call" => call}) do
      Redix.command(name, ["LPUSH", queue, msg])
    end
  end
end
