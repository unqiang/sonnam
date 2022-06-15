defmodule Sonnam.Crypto.SSL do
  @moduledoc false
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

  @spec load_pem(binary) :: term()
  def load_pem(pem) do
    pem
    |> :public_key.pem_decode()
    |> List.first()
    |> :public_key.pem_entry_decode()
  end
end
