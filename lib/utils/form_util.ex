defmodule Sonnam.Utils.FormUtil do
  @moduledoc false

  defmodule MalformedReturnValueError do
    defexception [:message]
  end

  @doc false
  def returning_tuple({mod, func, args}) do
    result = apply(mod, func, args)

    case result do
      {:ok, _} ->
        result

      {:error, _} ->
        result

      resp ->
        raise MalformedReturnValueError,
          message:
            "Expected `{:ok, result}` or `{:error, reason}` from #{mod}##{func}, got: #{inspect(resp)}"
    end
  end

  @spec with_ok(term) :: {:ok, term}
  def with_ok(val), do: {:ok, val}

  @spec from_ok({:ok, term}) :: term
  def from_ok({:ok, val}), do: val
end
