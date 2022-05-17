defmodule Sonnam.Aliyun.Utils do
  @moduledoc false

  defp rfc3986_encode(term) do
    term
    |> to_string()
    |> URI.encode_www_form()
    |> String.replace("+", "%20")
    |> String.replace("*", "%2A")
    |> String.replace("%7E", "~")
  end

  @doc """
  签名request
  """
  @spec sign(String.t(), map(), String.t()) :: String.t()
  def sign(verb, params, key) do
    verb
    |> encode_request(params)
    |> do_sign(key)
  end

  defp do_sign(string_to_sign, key) do
    :hmac
    |> :crypto.mac(:sha, key <> "&", string_to_sign)
    |> Base.encode64()
  end

  # 编码 requet: verb(GET|POST) + query_params
  @spec encode_request(String.t(), map()) :: <<_::16, _::_*8>>
  defp encode_request(verb, params) do
    verb <> "&" <> rfc3986_encode("/") <> "&" <> encode_params(params)
  end

  # 编码 query params
  @spec encode_params(map()) :: String.t()
  defp encode_params(params) do
    params
    |> Map.delete("Signature")
    |> Enum.sort()
    |> Enum.map(fn {k, v} ->
      rfc3986_encode(k) <> "=" <> rfc3986_encode(v)
    end)
    |> Enum.join("&")
    |> rfc3986_encode()
  end
end
