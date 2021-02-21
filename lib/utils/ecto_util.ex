defmodule Sonnam.Utils.EctoUtil do
  @moduledoc """
  Ecto utils
  """

  @wasted_fields [:__meta__, :removed_at, :inserted_at, :updated_at]

  def to_map(struct) do
    struct |> Map.from_struct() |> Map.drop(@wasted_fields)
  end
end
