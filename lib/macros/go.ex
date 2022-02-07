defmodule Sonnam.Macros.Go do
  @moduledoc false

  defmacro go(task) do
    quote do
      Task.start(fn -> unquote(task) end)
    end
  end
end
