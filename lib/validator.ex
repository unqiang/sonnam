defmodule Sonnam.Validator do
  @moduledoc """
  Declarative Validation

  Sample
  defmodule Validator do
    @type reason :: String.t()
    @type result :: %{data: Enum.t(), errors: [reason()]}

    @spec validate(Enum.t()) :: result()
    def validate(data) do
      result = %{
        data: data,
        errors: []
      }

      result
      |> validate_as_error(:username, [required()])
      |> validate_as_error(:password, [required()])
    end
  end

  %{}
  |> Validator.validate()
  |> IO.inspect()

  %{
    data: %{},
    errors: [password: ["is required"], username: ["is required"]]
  }
  """

  defp validate_key(initial_acc, category, key, validators) do
    value = get_in(initial_acc, [:data, key])

    Enum.reduce(validators, initial_acc, fn validator, acc ->
      case validator.(value) do
        :ok ->
          acc

        {:invalid, reason} ->
          update_in(acc, [category, key], fn
            nil -> [reason]
            other_reasons -> [reason | other_reasons]
          end)
      end
    end)
  end

  def validate_as_error(initial_acc, key, validators),
    do: validate_key(initial_acc, :errors, key, validators)

  def validate_as_warning(initial_acc, key, validators),
    do: validate_key(initial_acc, :warnings, key, validators)

  #
  # All kinds of validators
  #

  def required do
    reason = %{
      type: :required,
      desc: "The value is required, please include it in your configuration"
    }

    fn
      nil -> {:invalid, reason}
      _other -> :ok
    end
  end

  def type_allowed(allowed_types) do
    reason = %{
      type: :type_check,
      desc:
        "The value's type is only allowed in #{inspect(allowed_types)}, please check your input"
    }

    fn
      nil ->
        :ok

      x ->
        allowed_types
        |> Enum.member?(Typeable.typeof(x))
        |> case do
          true -> :ok
          false -> {:invalid, reason}
        end
    end
  end
end

defprotocol(Typeable, do: def(typeof(self)))
defimpl(Typeable, for: Atom, do: def(typeof(_), do: "Atom"))
defimpl(Typeable, for: BitString, do: def(typeof(_), do: "BitString"))
defimpl(Typeable, for: Float, do: def(typeof(_), do: "Float"))
defimpl(Typeable, for: Function, do: def(typeof(_), do: "Function"))
defimpl(Typeable, for: Integer, do: def(typeof(_), do: "Integer"))
defimpl(Typeable, for: List, do: def(typeof(_), do: "List"))
defimpl(Typeable, for: Map, do: def(typeof(_), do: "Map"))
defimpl(Typeable, for: PID, do: def(typeof(_), do: "PID"))
defimpl(Typeable, for: Port, do: def(typeof(_), do: "Port"))
defimpl(Typeable, for: Reference, do: def(typeof(_), do: "Reference"))
defimpl(Typeable, for: Tuple, do: def(typeof(_), do: "Tuple"))
