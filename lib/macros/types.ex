defmodule Sonnam.Macros.Types do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @type err_t :: {:error, any} | :error
      @type err_t(item) :: {:error, item} | :error

      @type ok_t :: {:ok, term()}
      @type ok_t(item) :: {:ok, item}
    end
  end
end
