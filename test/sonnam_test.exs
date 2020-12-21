defmodule SonnamTest do
  use ExUnit.Case
  doctest Sonnam

  test "greets the world" do
    assert Sonnam.hello() == :world
  end
end
