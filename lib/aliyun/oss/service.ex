defmodule Sonnam.AliyunOss.Service do
  @moduledoc false

  alias Sonnam.AliyunOss.{Client, Request}

  @spec post(Client.t(), String.t(), String.t() | nil, binary(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def post(cli, bucket, object, body, opts \\ []) do
    request(cli, "POST", bucket, object, body, opts)
  end

  @spec get(Client.t(), String.t() | nil, String.t() | nil, keyword()) ::
          {:ok, term()} | {:error, term()}
  def get(cli, bucket, object, opts \\ []) do
    request(cli, "GET", bucket, object, "", opts)
  end

  @spec put(Client.t(), String.t(), String.t() | nil, String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def put(cli, bucket, object, body, opts \\ []) do
    request(cli, "PUT", bucket, object, body, opts)
  end

  @spec delete(Client.t(), String.t(), String.t() | nil, keyword()) ::
          {:ok, term()} | {:error, term()}
  def delete(cli, bucket, object, opts \\ []) do
    request(cli, "DELETE", bucket, object, "", opts)
  end

  @spec head(Client.t(), String.t(), String.t() | nil, keyword()) ::
          {:ok, term()} | {:error, term()}
  def head(cli, bucket, object, opts \\ []) do
    request(cli, "HEAD", bucket, object, "", opts)
  end

  defp request(cli, verb, bucket, object, body, opts) do
    {host, resource} =
      case bucket do
        <<_, _::binary>> -> {"#{bucket}.#{cli.endpoint}", "/#{bucket}/#{object}"}
        _ -> {cli.endpoint, "/"}
      end

    %{
      verb: verb,
      body: body,
      host: host,
      path: "/#{object}",
      resource: resource,
      query_params: Keyword.get(opts, :query_params, %{}),
      headers: Keyword.get(opts, :headers, %{}),
      sub_resources: Keyword.get(opts, :sub_resources, %{})
    }
    |> Request.new!()
    |> Client.request(cli)
  end
end
