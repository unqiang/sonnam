defmodule Sonnam.Macros.Cache do
  @moduledoc """
  缓存框架
  store: 实现了resolve方法的存储模块
  mod: 实现了 set_dirty, get_dirty和get_source的模块

  NOTE: get_source实现 MUST NOT 返回nil结果!!!
  """

  @callback set_dirty(key :: String.t(), flag :: boolean()) :: :ok
  @callback get_dirty(key :: String.t()) :: boolean()
  @callback get_source(key :: String.t()) :: {:ok, term()}

  defmacro __using__(opts) do
    store = Keyword.get(opts, :store)
    mod = Keyword.get(opts, :mod)

    quote do
      @behaviour Sonnam.Macros.Cache

      @store unquote(store)
      @mod unquote(mod)

      @spec get_from_cache(key :: String.t(), ttl :: non_neg_integer) :: {:ok, term()}
      def get_from_cache(key, ttl) do
        resolver = fn ->
          apply(@mod, :get_source, [key])
        end

        {:ok, res} =
          apply(@mod, :get_dirty, [key])
          |> if do
            apply(@store, :resolve, [key, resolver, 0])
          else
            apply(@store, :resolve, [key, resolver, ttl])
          end

        apply(@mod, :set_dirty, [key, false])
        {:ok, res}
      end
    end
  end
end
