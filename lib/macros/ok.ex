defmodule Sonnam.Macros.OK do
  @moduledoc false

  defmacro with_ok(obj) do
    quote do
      the_obj = unquote(obj)

      case the_obj do
        {:ok, item} -> {:ok, item}
        {:error, error} -> {:error, error}
        others -> {:ok, others}
      end
    end
  end

  defmacro from_ok(obj) do
    quote do
      the_obj = unquote(obj)

      case the_obj do
        {:ok, item} -> item
        {:error, error} -> {:error, error}
        others -> others
      end
    end
  end

  defmacro ok_pipe(obj, func) do
    quote do
      the_obj = unquote(obj)
      the_func = unquote(func)

      case the_obj do
        {:ok, val} -> the_func.(val) |> with_ok()
        others -> others
      end
    end
  end
end
