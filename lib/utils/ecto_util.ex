defmodule Sonnam.Utils.EctoUtil do
  @moduledoc """
  Ecto utils
  """

  @wasted_fields [:__meta__, :removed_at, :inserted_at, :updated_at]

  @doc """
  convert ecto model struct to map
  """
  def to_map(struct) do
    struct |> Map.from_struct() |> Map.drop(@wasted_fields)
  end

  @doc """
  match 2 lists by specific key

  ## Examples

  iex> a = [%{id: 1, a: 1}, %{id: 2, a: 2}]
  iex> b = [%{id: 1, b: 1}, %{id: 2, b: 2}]
  iex> Sonnam.Utils.EctoUtil.match_by(a, b, :id)
  [{%{a: 1, id: 1}, [%{b: 1, id: 1}]}, {%{a: 2, id: 2}, [%{b: 2, id: 2}]}]
  """
  def match_by(list_a, list_b, key) do
    b_map = Enum.group_by(list_b, &(Map.get(&1, key)))
    Enum.map(list_a, &{&1, Map.get(b_map, Map.get(&1, key))})
  end
end
