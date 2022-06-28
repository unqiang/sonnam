defmodule Sonnam.Utils.Time do
  @moduledoc """
  Time related utilities module.
  """

  @epoch_seconds :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  @doc """
  Get the local time.

  Return value is a `DateTime`, for instance `#DateTime<2018-04-18 17:45:29Z>`
  """
  @spec get_local_time() :: struct
  def get_local_time() do
    :erlang.localtime()
    |> erlangtime_to_datetime()
  end

  @doc """
  Get the local time representation of a `timestamp`.

  Return value is a `DateTime`, for instance `#DateTime<2018-04-18 17:45:29Z>`
  """
  def get_local_time(timestamp) do
    timestamp
    |> timestamp_to_erlangtime()
    |> :calendar.universal_time_to_local_time()
    |> erlangtime_to_datetime()
  end

  @doc """
  Convert a unix `timestamp` to an erlang time.

  Return value is an erlang time, for instance `{{2018, 4, 25}, {18, 37, 17}}`
  """
  def timestamp_to_erlangtime(timestamp) do
    (timestamp + @epoch_seconds)
    |> :calendar.gregorian_seconds_to_datetime()
  end

  @doc """
  Convert an erlang time to a unix timestamp.

  Return value is a unix timestamp, for instance `1524652637`
  """
  def erlangtime_to_timestamp(erltime) do
    :calendar.datetime_to_gregorian_seconds(erltime) - @epoch_seconds
  end

  @doc """
  Convert an erlang time to an Elixir `DateTime`.

  Return value is an Elixir `DateTime`, for instance `#DateTime<2018-04-25 18:37:17Z>`
  """
  def erlangtime_to_datetime({date, time} = _erltime) when tuple_size(time) == 3 do
    elem(
      DateTime.from_iso8601(
        Date.to_iso8601(Date.from_erl!(date)) <>
          "T" <> Time.to_iso8601(Time.from_erl!(time)) <> "Z"
      ),
      1
    )
  end

  def erlangtime_to_datetime({date, time} = _erltime) when tuple_size(time) > 3 do
    time = List.to_tuple(for x <- 0..2, do: elem(time, x))

    elem(
      DateTime.from_iso8601(
        Date.to_iso8601(Date.from_erl!(date)) <>
          "T" <> Time.to_iso8601(Time.from_erl!(time)) <> "Z"
      ),
      1
    )
  end

  @doc """
  Convert an Elixir `DateTime` to erlang time format.

  Return value is an erlang time, for instance `{{2018, 4, 25}, {18, 37, 17}}`
  """
  def datetime_to_erlangtime(datetime) do
    {Date.to_erl(DateTime.to_date(datetime)), Time.to_erl(DateTime.to_time(datetime))}
  end

  @doc """
  Convert a standard datetime string `"2018-04-25 18:07:33"` to erlang time format.

  Return value is an erlang time, for instance `{{2018, 4, 25}, {18, 7, 33}}`
  """
  def string_to_erlangtime(str_datetime) do
    [d, t] = String.split(str_datetime, " ")
    d = String.split(d, "-") |> Enum.map(fn x -> String.to_integer(x) end) |> List.to_tuple()
    t = String.split(t, ":") |> Enum.map(fn x -> String.to_integer(x) end) |> List.to_tuple()
    {d, t}
  end

  @doc """
  Convert an erlang time to a standard datetime string.

  Return value is a standard datetime string, for instance `"2018-04-25 18:07:33"`
  """
  def erlangtime_to_string({date, time} = _erltime) when tuple_size(time) == 3 do
    Date.to_iso8601(Date.from_erl!(date)) <> " " <> Time.to_iso8601(Time.from_erl!(time))
  end

  def erlangtime_to_string({date, time} = _erltime) when tuple_size(time) > 3 do
    time = List.to_tuple(for x <- 0..2, do: elem(time, x))
    Date.to_iso8601(Date.from_erl!(date)) <> " " <> Time.to_iso8601(Time.from_erl!(time))
  end
end
