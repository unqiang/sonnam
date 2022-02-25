defmodule Sonnam.AliyunOss.Client do
  @moduledoc false

  use Strukt

  alias Sonnam.AliyunOss.Request

  defstruct do
    field(:endpoint, :string)
    field(:access_key_id, :string)
    field(:access_key_secret, :string)
  end

  @spec request(Request.t(), %__MODULE__{}) :: {:ok, binary} | {:error, String.t()}
  def request(req, cli) do
    req
    |> Request.build_signed(cli)
    |> do_request()
    |> case do
      {:ok, %HTTPoison.Response{body: body, status_code: status_code}}
      when status_code in 200..299 ->
        {:ok, body}

      {:ok, %HTTPoison.Response{body: body, status_code: status_code}} ->
        {:error, "#{status_code}:#{body}"}

      _ ->
        {:error, "Internal server error"}
    end
  end

  defp do_request(req) when req.verb == "GET" do
    req
    |> Request.query_url()
    |> HTTPoison.get(req.headers)
  end

  defp do_request(req) when req.verb == "POST" do
    req
    |> Request.query_url()
    |> HTTPoison.post(req.body, req.headers)
  end

  defp do_request(req) when req.verb == "PUT" do
    req
    |> Request.query_url()
    |> HTTPoison.put(req.body, req.headers)
  end

  defp do_request(req) when req.verb == "DELETE" do
    req
    |> Request.query_url()
    |> HTTPoison.delete(req.headers)
  end

  defp do_request(req) when req.verb == "HEAD" do
    req
    |> Request.query_url()
    |> HTTPoison.head(req.headers)
  end
end
