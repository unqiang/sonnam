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

  @spec start_link(pub_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    {name, args} = Keyword.pop(args, :name, :pub)

    pool_opts = [
      name: {:local, name},
      worker_module: Redix,
      size: 2,
      max_overflow: 1
    ]

    children = [
      :poolboy.child_spec(name, pool_opts, args)
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(name, command) do
    :poolboy.transaction(name, &Redix.command(&1, command))
  end

  def pipeline(name, commands) do
    :poolboy.transaction(name, &Redix.pipeline(&1, commands))
  end

  @spec pub_to(atom(), queue: String.t(), call: String.t(), body: term()) :: {:ok, integer()}
  def pub_to(name, queue: queue, call: call, body: body) do
    with {:ok, msg} <- Jason.encode(%{"call" => call, "body" => body}) do
      command(name, ["LPUSH", queue, msg])
    end
  end

  @spec pub_to(atom(), queue: String.t(), call: String.t()) :: {:ok, integer()}
  def pub_to(name, queue: queue, call: call) do
    with {:ok, msg} <- Jason.encode(%{"call" => call}) do
      command(name, ["LPUSH", queue, msg])
    end
  end
end
