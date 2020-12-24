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
    children = [
      {Redix, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec new_job(atom(), String.t(), String.t(), integer()) :: {:ok, term()}
  def new_job(name, svc, job_id, eta) do
    bucket = "#{svc}-#{Base.gen_bucket(eta)}"

    # check bucket exists
    Redix.command(name, ["EXISTS", bucket])
    |> case do
      # already exists
      {:ok, 1} ->
        Redix.command(name, ["ZADD", bucket, eta, job_id])

      _ ->
        Redix.pipeline(name, [["ZADD", bucket, eta, job_id], ["EXPIRE", bucket, 86400]])
    end
  end
end
