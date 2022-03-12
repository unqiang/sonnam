defmodule Sonnam.Macros.Go do
  @moduledoc false

  defmacro go(supervisor, task) do
    quote do
      Task.Supervisor.start_child(unquote(supervisor), fn -> unquote(task) end,
        restart: :transient
      )
    end
  end
end
