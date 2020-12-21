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
    children = [
      {Redix, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  #### cache part ####

  @doc """
  add a new cache key/value

  * `name` - cache service name, genserver name
  * `key`  - key of cache
  * `value` - value of cache
  * `expire` - how many seconds this cache pair can survive

  ## Examples

  iex> Sonnam.Kvsrv.RedisCache.put(:cache, "foo", "bar", 5)
  {:ok, "OK"}
  """
  def put(name, key, value, expire) do
    Redix.command(name, ["SETEX", key, expire, value])
  end

  @doc """
  get cache value by key

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Sonnam.Kvsrv.RedisCache.get(:cache, "foo")
  {:ok, "bar"}
  """
  def get(name, key) do
    Redix.command(name, ["GET", key])
  end

  @doc """
  check if key in cache table

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Sonnam.Kvsrv.RedisCache.exists?(:cache, "foo")
  false
  """
  def exist?(name, key) do
    case Redix.command(name, ["GET", key]) do
      {:ok, nil} -> false
      _ -> true
    end
  end

  @doc """
  drop a cache pair

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Sonnam.Kvsrv.RedisCache.del(:cache, "foo")
  {:ok, 1}
  """
  def del(name, key) do
    Redix.command(name, ["DEL", key])
  end
end
