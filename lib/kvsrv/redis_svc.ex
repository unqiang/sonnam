defmodule Sonnam.Kvsrv.RedisSvc do
  @moduledoc """
  redis svc
  """
  @behaviour NimblePool

  @type command_t :: [binary() | bitstring()]

  @spec command(atom | pid | {atom, any} | {:via, atom, any}, command_t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def command(pool, command, opts \\ []) do
    pool_timeout = Keyword.get(opts, :pool_timeout, 5000)

    NimblePool.checkout!(
      pool,
      :checkout,
      fn _, conn ->
        conn
        |> Redix.command(command)
        |> then(fn x -> {x, conn} end)
      end,
      pool_timeout
    )
  end

  @spec pipeline(atom | pid | {atom, any} | {:via, atom, any}, [command_t()], keyword) ::
          {:ok, term()} | {:error, term()}
  def pipeline(pool, commands, opts \\ []) do
    pool_timeout = Keyword.get(opts, :pool_timeout, 5000)

    NimblePool.checkout!(
      pool,
      :checkout,
      fn _, conn ->
        conn
        |> Redix.pipeline(commands)
        |> then(fn x -> {x, conn} end)
      end,
      pool_timeout
    )
  end

  @impl NimblePool
  @spec init_worker(String.t()) :: {:ok, pid, any}
  def init_worker(redis_url = pool_state) do
    {:ok, conn} = Redix.start_link(redis_url)
    {:ok, conn, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, conn, pool_state) do
    {:ok, conn, conn, pool_state}
    # with {:ok, "PONG"} <- Redix.command(conn, ["PING"]) do
    #   {:ok, conn, conn, pool_state}
    # else
    #   _ -> {:remove, :closed, pool_state}
    # end
  end

  @impl NimblePool
  def handle_checkin(conn, _, _old_conn, pool_state) do
    {:ok, conn, pool_state}
  end

  @impl NimblePool
  def handle_info(:close, _conn), do: {:remove, :closed}
  def handle_info(_, conn), do: {:ok, conn}

  @impl NimblePool
  def terminate_worker(_reason, conn, pool_state) do
    Redix.stop(conn)
    {:ok, pool_state}
  end
end
