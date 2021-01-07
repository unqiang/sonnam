defmodule Sonnam.EtaQueue.Client do
  @moduledoc """
  etaqueue client
  """
  use Supervisor
  alias Sonnam.EtaQueue.Base

  @type eta_cli_opts :: [
          name: atom(),
          host: String.t(),
          port: integer(),
          password: String.t()
        ]

  @type event :: {String.t(), String.t()}

  @spec start_link(eta_cli_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(args) do
    {name, args} = Keyword.pop(args, :name, :eta_q_cli)

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

  def command(name, command) do
    :poolboy.transaction(name, &Redix.command(&1, command))
  end

  def pipeline(name, commands) do
    :poolboy.transaction(name, &Redix.pipeline(&1, commands))
  end

  @spec new_job(atom(), String.t(), String.t(), integer()) :: {:ok, term()}
  def new_job(name, svc, job_id, eta) do
    bucket = "#{svc}-#{Base.gen_bucket(eta)}"

    # check bucket exists
    command(name, ["EXISTS", bucket])
    |> case do
      # already exists
      {:ok, 1} ->
        command(name, ["ZADD", bucket, eta, job_id])

      _ ->
        pipeline(name, [["ZADD", bucket, eta, job_id], ["EXPIRE", bucket, 86400]])
    end
  end
end
