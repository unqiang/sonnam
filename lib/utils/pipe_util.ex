defmodule Sonnam.Utils.PipeUtil do
  @moduledoc false
  @deprecated "use Sonnam.Macros.OK instead"

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

  @spec with_ok(term) :: {:ok, term} | err()
  def with_ok({:ok, val}), do: {:ok, val}
  def with_ok({:error, val}), do: {:error, val}
  def with_ok(val), do: {:ok, val}

  @spec from_ok({:ok, term}) :: term
  def from_ok({:ok, val}), do: val
  def from_ok(val), do: val

  @spec ok_pipe({:ok, term()} | err(), fun()) :: {:ok, term()} | err()
  def ok_pipe(resp, func) do
    resp
    |> case do
      {:ok, nil} -> {:ok, nil}
      {:ok, ret} -> func.(ret) |> with_ok
      other -> other
    end
  end

  @doc """
  match 2 lists by specific key

  ## Examples

  iex> a = [%{id: 1, a: 1}, %{id: 2, a: 2}]
  iex> b = [%{id: 1, b: 1}, %{id: 2, b: 2}]
  iex> Sonnam.Utils.EctoUtil.match_by(a, b, :id)
  [{%{a: 1, id: 1}, [%{b: 1, id: 1}]}, {%{a: 2, id: 2}, [%{b: 2, id: 2}]}]
  """
  def match_by(list_a, list_b, key) do
    b_map = Enum.group_by(list_b, &(Map.get(&1, key)))
    Enum.map(list_a, &{&1, Map.get(b_map, Map.get(&1, key))})
  end

end
