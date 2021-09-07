defmodule Sonnam.Kvsrv.RedisSvc do
  @moduledoc """
  redis svc
  """

  use Supervisor

  @type redis_opts :: [name: atom(), uri: String.t()]

  @spec start_link(redis_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    [name: name, uri: uri] = opts

    pool_opts = [
      name: {:local, name},
      worker_module: Redix,
      size: 10,
      max_overflow: 5
    ]

    children = [
      :poolboy.child_spec(name, pool_opts, uri)
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(name, command) do
    :poolboy.transaction(name, &Redix.command(&1, command))
  end

  def pipeline(name, commands) do
    :poolboy.transaction(name, &Redix.pipeline(&1, commands))
  end
end
