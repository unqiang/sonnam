defmodule Sonnam.AliyunOss.Util do
  @moduledoc false

  # -------------- sign -------------
  @doc """
  签名字符串
  """
  @spec sign(String.t(), String.t()) :: String.t()
  def sign(string_to_sign, key) do
    :crypto.mac(:hmac, :sha, key, string_to_sign)
    |> Base.encode64()
  end

  @doc """
  签名request
  """
  @spec sign(String.t(), map(), String.t()) :: String.t()
  def sign(verb, params, key) do
    sign(encode_request(verb, params), key)
  end

  # ----------- encoder --------------
  @spec encode_string(String.t()) :: String.t()
  defp encode_string(term) do
    term
    |> to_string()
    |> URI.encode_www_form()
    |> String.replace("+", "%20")
  end

  @doc """
  编码 requet: verb(GET|POST) + query_params
  """
  @spec encode_request(String.t(), map()) :: <<_::16, _::_*8>>
  def encode_request(verb, params) do
    verb <> "&" <> encode_string("/") <> "&" <> encode_params(params)
  end

  @doc """
  编码 query params
  """
  @spec encode_params(map()) :: String.t()
  def encode_params(params) do
    params
    |> Map.delete("Signature")
    |> Enum.sort()
    |> Stream.map(fn {k, v} ->
      encode_string(k) <> "=" <> encode_string(v)
    end)
    |> Enum.join("&")
    |> encode_string()
  end


  # ------------ time ------------
  @doc """
  e.g.
  "Tue, 27 Nov 2018 04:58:42 GMT"
  """
  def gmt_now() do
    Sonnam.Utils.TimeUtil.now()
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end
end
