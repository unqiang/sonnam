defmodule Sonnam.Utils.CryptoUtil do
  @moduledoc """
  加密工具
  """

  @doc """
  md5
  """
  @spec md5(String.t()) :: binary()
  def md5(plaintext), do: :crypto.hash(:md5, plaintext)

  @doc """
  sha1
  """
  @spec sha(String.t()) :: binary()
  def sha(plaintext), do: :crypto.hash(:sha, plaintext)

  @doc """
  sha256
  """
  @spec sha256(String.t()) :: binary()
  def sha256(plaintext), do: :crypto.hash(:sha256, plaintext)

  @doc """
  generate random string
  ## Example

  iex(17)> Common.Crypto.random_string 16
  "2jqDlUxDuOt-qyyZ"
  """
  @spec random_string(integer()) :: String.t()
  def random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  @doc """
  generate id with prefix and tail

  ## Examples

  iex> generate_id("U", 4)
  "U16219286427399"
  """
  @spec generate_id(String.t(), integer()) :: String.t()
  def generate_id(prefix, tail_len) do
    tail =
      1..tail_len
      |> Enum.map(fn _ -> Enum.random(0..9) end)
      |> Enum.join()

    "#{prefix}#{:os.system_time(:seconds)}#{tail}"
  end

  #### ssl tools
  defp decode_public(nil), do: nil

  defp decode_public(pem) do
    [{:Certificate, der_bin, :not_encrypted}] = :public_key.pem_decode(pem)
    der_bin
  end

  defp decode_private(pem) do
    [{type, der_bin, :not_encrypted}] = :public_key.pem_decode(pem)
    {type, der_bin}
  end

  @spec load_ssl(Keyword.t()) :: [any()]
  def load_ssl([]), do: []

  def load_ssl(ssl) do
    ssl = Enum.into(ssl, %{})

    [
      cacerts: ssl.ca_cert |> decode_public() |> List.wrap(),
      cert: ssl.cert |> decode_public(),
      key: ssl.key |> decode_private()
    ]
    |> Enum.reject(fn {_k, v} -> v == nil end)
  end
end
