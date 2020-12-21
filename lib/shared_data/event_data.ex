defmodule Sonnam.SharedData.Event do
  @moduledoc """
  pubsub event shared data
  """

  def event_ping(), do: {"queue_sugar", "ping"}
end
