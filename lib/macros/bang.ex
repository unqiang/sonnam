defmodule Sonnam.Macros.Bang do
  @moduledoc """
  easy generate !function
  """

  defmacro __using__(_opts) do
    quote do
      import Sonnam.Macros.Bang
    end
  end

  defmacro defbang({name, _, args}) do
    args = if is_list(args), do: args, else: []

    quote bind_quoted: [name: Macro.escape(name), args: Macro.escape(args)] do
      def unquote((to_string(name) <> "!") |> String.to_atom())(unquote_splicing(args)) do
        case unquote(name)(unquote_splicing(args)) do
          :ok ->
            :ok

          {:ok, result} ->
            result

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defmacro defbang({name, _, args}, to: mod) do
    args = if is_list(args), do: args, else: []

    quote bind_quoted: [
            mod: Macro.escape(mod),
            name: Macro.escape(name),
            args: Macro.escape(args)
          ] do
      def unquote((to_string(name) <> "!") |> String.to_atom())(unquote_splicing(args)) do
        case unquote(mod).unquote(name)(unquote_splicing(args)) do
          :ok ->
            :ok

          {:ok, result} ->
            result

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end
end
