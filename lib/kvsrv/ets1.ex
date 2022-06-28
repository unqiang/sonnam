defmodule  Sonnam.Kvsrv.Ets1 do
      use GenServer
      require Logger

      @table __MODULE__
      @ttl 100
      @type resolver_t :: (() -> {:ok, term()} | {:error, any()})

      def start_link() do
        GenServer.start_link(__MODULE__, :ok, [])
      end

      @spec put(key :: term(), value :: term()) :: {:ok, non_neg_integer}
      def put(key, value) do
        true = :ets.insert(@table, {key, value, timestamp()})
        {:ok, 1}
      end

      @spec get(key :: term(), ttl :: integer, delete_expired? :: boolean) ::
              {:ok, term()} | :miss
      def get(key, ttl \\ @ttl, delete_expired? \\ false) do
        :ets.lookup(@table, key)
        |> case do
          [{^key, val, ts}] ->
            (timestamp() - ts <= ttl)
            |> if do
              {:ok, val}
            else
              delete_expired?
              |> if do
                delete(key)
              end

              :miss
            end

          _else ->
            :miss
        end
      end

      @spec delete(String.t()) :: boolean()
      def delete(key) do
        :ets.delete(@table, key)
      end

      @spec resolve(key :: String.t(), resolver :: resolver_t(), ttl :: non_neg_integer) ::
              {:ok, term} | {:error, any}
      def resolve(key, resolver, ttl \\ @ttl) when is_function(resolver, 0) do
        get(key, ttl, false)
        |> case do
          :miss ->
            with {:ok, res} <- resolver.() do
              put(key, res)
              {:ok, res}
            end

          {:ok, term} ->
            {:ok, term}
        end
      end

      defp garbbage_collection() do
       :ets.insert(@table, {timestamp()})
       # :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", timestamp() - @ttl}], [true]}])
      end

      def init(:ok) do
        table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        ## 启动定时器,间隔6s
        # :timer.send_interval(6000, :prune)
        :erlang.send_after(6000, self(), :prune)
        {:ok, table}
      end

      def handle_info(:prune, table) do
        Logger.info("run ets garbbage collection....#{timestamp()}")
        garbbage_collection()
        :erlang.send_after(6000, self(), :prune)
        {:noreply, table}
      end

      defp timestamp()  do
         DateTime.to_unix(DateTime.utc_now())
      end
end
