defmodule Sonnam.Macros.Assertion do
  @moduledoc """
  断言工具
  """

  defmacro do_assert(assert_fn, error_msg) do
    quote do
      unquote(assert_fn).()
      |> case do
        true -> :ok
        false -> {:error, unquote(error_msg)}
      end
    end
  end
end
