defmodule Sonnam.EtaQueue.Base do
  @moduledoc """
  common function for etaqueue
  """
  @spec gen_bucket(integer()) :: String.t()
  def gen_bucket(eta) do
    {:ok, datetime} = DateTime.from_unix(eta)

    datetime =
      datetime.hour
      |> case do
        23 -> DateTime.add(datetime, 3600, :second)
        _ -> datetime
      end

    [datetime.year, datetime.month, datetime.day]
    |> Enum.map(&to_string(&1))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join("")
  end
end
