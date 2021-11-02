defmodule Sonnam.Utils.FormUtil do
  @moduledoc false

  defmodule MalformedReturnValueError do
    defexception [:message]
  end

  @type err :: {:error, any()}

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
  def with_ok({:ok, val}), do: {:ok, val}
  def with_ok(val), do: {:ok, val}

  @spec from_ok({:ok, term}) :: term
  def from_ok({:ok, val}), do: val

  @spec ok_pipe({:ok, term()} | err(), fun()) :: {:ok, term()} | err()
  def ok_pipe(resp, func) do
    resp
    |> case do
      {:ok, nil} -> {:ok, nil}
      {:ok, ret} -> func.(ret) |> with_ok
      other -> other
    end
  end
end
