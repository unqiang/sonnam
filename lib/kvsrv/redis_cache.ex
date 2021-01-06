defmodule Sonnam.Kvsrv.RedisCache do
  @moduledoc """
  redis cache

  ## Config example
  ```
  config :my_app, :cache,
    name: :cache,
    host: "localhost",
    port: 6379
  ```

  ## Usage:
  ```
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {RedisCache, Application.get_env(:my_app, :cache)},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  """

  use Supervisor

  @type cache_opts :: [name: atom(), host: String.t(), port: integer(), password: String.t()]

  @spec start_link(cache_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    {name, args} = Keyword.pop(args, :name, :cache)

    pool_opts = [
      name: {:local, name},
      worker_module: Redix,
      size: 10,
      max_overflow: 5
    ]

    children = [
      :poolboy.child_spec(name, pool_opts, args)
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(command) do
    :poolboy.transaction(:cache, &Redix.command(&1, command))
  end

  def pipeline(commands) do
    :poolboy.transaction(:cache, &Redix.pipeline(&1, commands))
  end
end
