defmodule Sonnam.AliyunOss.Object do
  @moduledoc false

  alias Sonnam.AliyunOss.Service

  @spec put_object(Client.t(), String.t(), String.t() | nil, String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def put_object(cli, bucket, object, body, opts \\ []) do
    Service.put(cli, bucket, object, body, opts)
  end
end