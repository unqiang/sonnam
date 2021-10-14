defmodule Sonnam.Utils.TimeUtil do
  @moduledoc """
  时间相关工具
  """

  @doc """
  get current timestamp
  ## Example
  iex> Common.TimeTool.timestamp(:seconds)
  1534466694
  iex> Common.TimeTool.timestamp(:milli_seconds)
  1534466732335
  iex> Common.TimeTool.timestamp(:micro_seconds)
  1534466750683862
  iex> Common.TimeTool.timestamp(:nano_seconds)
  1534466778949821000
  """
  @spec timestamp(atom()) :: integer()
  def timestamp(typ \\ :seconds), do: :os.system_time(typ)

  @spec now(Calendar.time_zone()) :: DateTime.t()
  def now(tz \\ "Etc/UTC"), do: DateTime.now!(tz)

  def naive_now(typ \\ :second),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(typ)

  @spec china_now() :: DateTime.t()
  def china_now(), do: now("Asia/Shanghai")

  @spec china_now_str() :: String.t()
  def china_now_str(), do: china_now() |> datetime_to_str()

  @spec china_now_date() :: String.t()
  def china_now_date() do
    china_now()
    |> datetime_to_str("%Y-%m-%d")
  end

  @doc """
  convert timestamp to time string

  * `ts`     - timestamp
  * `tz`     - timezone default Shanghai

  ## Examples

  iex> Sonnam.Utils.TimeUtil.ts_to_str(1607915375)
  "2020-12-14 11:09:35"
  """
  @spec ts_to_str(integer(), Calendar.time_zone()) :: String.t()
  def ts_to_str(ts, tz \\ "Asia/Shanghai") do
    ts
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!(tz)
    |> datetime_to_str()
  end

  @doc """
  convert timestamp to datetime

  * `ts`     - timestamp
  * `tz`     - timezone default Shanghai

  ## Examples

  iex> Sonnam.Utils.TimeUtil.ts_to_datetime(1607915375, "Etc/UTC")
  ~U[2020-12-14 03:09:35Z]
  """
  @spec ts_to_datetime(integer(), Calendar.time_zone()) :: DateTime.t()
  def ts_to_datetime(ts, tz \\ "Asia/Shanghai") do
    ts
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!(tz)
  end

  @doc """
  convert datetime to timestamp

  * `datetime`     - datetime

  ## Examples

  iex> Sonnam.Utils.TimeUtil.datetime_to_ts ~U[2020-12-14 03:09:35Z]
  1607915375
  """
  @spec datetime_to_ts(DateTime.t()) :: integer()
  def datetime_to_ts(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.to_unix()
  end

  @doc """
  convert datetime to timestamp

  * `datetime`     - datetime
  """
  @spec datetime_to_str(DateTime.t()) :: String.t()
  def datetime_to_str(datetime, format \\ "%Y-%m-%d %H:%M:%S") do
   Calendar.strftime(datetime, format)
  end

  @spec china_str_to_ts(String.t()) :: integer()
  def china_str_to_ts(datetime_str) do
    datetime_str
    |> china_str_to_datetime()
    |> datetime_to_ts()
  end

  @spec china_str_to_datetime(String.t()) :: DateTime.t() | nil
  def china_str_to_datetime(""), do: nil

  def china_str_to_datetime(datetime_str) do
    [date, time] = String.split(datetime_str)
    {:ok, datetime, _} = DateTime.from_iso8601(date <> "T" <> time <> "+08:00")
    datetime
  end

  @spec china_str_to_naive(String.t()) :: NaiveDateTime.t() | nil
  def china_str_to_naive(""), do: nil

  def china_str_to_naive(str) do
    str
    |> china_str_to_datetime()
    |> case do
      nil ->
        nil

      dt ->
        dt
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.to_naive()
    end
  end

  @spec naive_datetime_to_str(NaiveDateTime.t(), Calendar.time_zone()) :: String.t()
  def naive_datetime_to_str(datetime, tz \\ "Asia/Shanghai") do
    datetime
    |> (fn
          nil ->
            ""

          dt ->
            dt
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.shift_zone!(tz)
            |> datetime_to_str()
        end).()
  end

  @spec naive_to_china_str(NaiveDateTime.t()) :: String.t()
  def naive_to_china_str(nil), do: ""
  def naive_to_china_str(nt), do: naive_datetime_to_str(nt)



  @spec naive_to_datetime(NaiveDateTime.t(), Calendar.time_zone()) :: DateTime.t()
  def naive_to_datetime(ndt, tz \\ "Asia/Shanghai") do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.shift_zone!(tz)
  end
end
