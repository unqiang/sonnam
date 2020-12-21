defmodule Sonnam.EtaQueue.Server do
  @moduledoc """
  etaqueue server
  """

  use Supervisor

  @type eta_server_opts :: [
          job_handler: atom(),
          name: atom(),
          host: String.t(),
          port: integer(),
          password: String.t()
        ]

  @type event :: {String.t(), String.t()}

  @spec start_link(eta_server_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    {handler, args} = Keyword.pop(args, :job_handler)
    name = Keyword.get(args, :name)

    children = [
      {Redix, args},
      {Task, fn -> loop(name, handler) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def loop(name, handler) do
    now_ts = Sonnam.Utils.TimeUtil.timestamp()

    now_bucket =
      now_ts
      |> Sonnam.EtaQueue.Base.gen_bucket()

    bucket = to_string(name) <> now_bucket

    # 懒惰的我不想加锁
    Redix.command(name, ["EXISTS", bucket])
    |> case do
      {:ok, 1} ->
        {:ok, job_id_list} = Redix.command(name, ["ZRANGEBYSCORE", bucket, "-inf", now_ts])
        Redix.command(name, ["ZREM", bucket | job_id_list])
        apply(handler, :process, [job_id_list])

        Process.sleep(1000)
        loop(name, handler)

      _ ->
        # no job now
        Process.sleep(10000)
        loop(name, handler)
    end
  end
end
