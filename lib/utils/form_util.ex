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
end
