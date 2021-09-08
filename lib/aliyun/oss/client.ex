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

defmodule Sonnam.AliyunOss.Request do
  @moduledoc false

  use Strukt

  defstruct do
    field(:verb, :string)
    field(:host, :string)
    field(:path, :string)
    field(:scheme, :string, default: "https")
    field(:resource, :string)
    field(:query_params, :map)
    field(:sub_resources, :map)
    field(:body, :binary)
    field(:headers, :map)
    field(:expires, :integer)
  end

  def new!(params) do
    {:ok, m} = new(params)
    m
  end

  defp ensure_essential_headers(%__MODULE__{} = req) do
    headers =
      req.headers
      |> Map.put_new("Host", req.host)
      |> Map.put_new_lazy("Content-Type", fn -> parse_content_type(req) end)
      |> Map.put_new_lazy("Content-MD5", fn -> calc_content_md5(req) end)
      |> Map.put_new_lazy("Content-Length", fn -> byte_size(req.body) end)
      |> Map.put_new_lazy("Date", fn -> Sonnam.AliyunOss.Util.gmt_now() end)

    Map.put(req, :headers, headers)
  end

  def query_url(req) do
    URI.to_string(%URI{
      scheme: req.scheme,
      host: req.host,
      path: req.path,
      query: Map.merge(req.query_params, req.sub_resources) |> URI.encode_query()
    })
  end

  def build_signed(params, cli) do
    params
    |> new!()
    |> ensure_essential_headers()
    |> set_authorization_header(cli)
  end

  defp set_authorization_header(req, cli) do
    update_in(req.headers["Authorization"], fn _ ->
      "OSS " <> cli.access_key_id <> ":" <> gen_signature(cli, req)
    end)
  end

  def gen_signature(cli, req) do
    req
    |> string_to_sign()
    |> Sonnam.AliyunOss.Util.sign(cli.access_key_secret)
  end

  defp canonicalize_oss_headers(%{headers: headers}) do
    headers
    |> Stream.filter(&is_oss_header?/1)
    |> Stream.map(&encode_header/1)
    |> Enum.join("\n")
    |> case do
      "" -> ""
      str -> str <> "\n"
    end
  end

  defp is_oss_header?({h, _}) do
    Regex.match?(~r/^x-oss-/i, to_string(h))
  end

  defp encode_header({h, v}) do
    (h |> to_string() |> String.downcase()) <> ":" <> to_string(v)
  end

  defp canonicalize_query_params(%{query_params: query_params}) do
    query_params
    |> Stream.map(fn {k, v} -> "#{k}:#{v}\n" end)
    |> Enum.join()
  end

  defp canonicalize_resource(%{resource: resource, sub_resources: nil}), do: resource

  defp canonicalize_resource(%{resource: resource, sub_resources: sub_resources}) do
    sub_resources
    |> Stream.map(fn
      {k, nil} -> k
      {k, v} -> "#{k}=#{v}"
    end)
    |> Enum.join("&")
    |> case do
      "" -> resource
      query_string -> resource <> "?" <> query_string
    end
  end

  defp parse_content_type(%{resource: resource}) do
    case Path.extname(resource) do
      "." <> name -> MIME.type(name)
      _ -> "application/octet-stream"
    end
  end

  defp string_to_sign(%__MODULE__{scheme: "rtmp"} = req) do
    expires_time(req) <>
      "\n" <>
      canonicalize_query_params(req) <> canonicalize_resource(req)
  end

  defp string_to_sign(%__MODULE__{} = req) do
    req.verb <>
      "\n" <>
      header_content_md5(req) <>
      "\n" <>
      header_content_type(req) <>
      "\n" <>
      expires_time(req) <>
      "\n" <>
      canonicalize_oss_headers(req) <> canonicalize_resource(req)
  end

  defp expires_time(%{expires: expires} = req), do: (expires || header_date(req)) |> to_string()

  defp header_content_md5(%{headers: %{"Content-MD5" => md5}}), do: md5
  defp header_content_type(%{headers: %{"Content-Type" => content_type}}), do: content_type
  defp header_date(%{headers: %{"Date" => date}}), do: date

  defp calc_content_md5(%{body: ""}), do: ""

  defp calc_content_md5(%{body: body}) do
    :crypto.hash(:md5, body) |> Base.encode64()
  end
end
