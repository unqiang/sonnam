defmodule Sonnam.Crypto.AES128CBC do
  @moduledoc false
  @block_size 16

  @type key :: <<_::128>>
  @type iv :: <<_::128>>

  @spec encrypt(binary, key(), iv()) :: binary
  def encrypt(plaintext, secret_key, iv) do
    plaintext = pkcs5padding(plaintext, @block_size)
    encrypted_text = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, plaintext, true)
    Base.encode64(encrypted_text)
  end

  @spec decrypt(binary, key(), iv()) :: binary
  def decrypt(ciphertext, secret_key, iv) do
    {:ok, ciphertext} = Base.decode64(ciphertext)
    decrypted_text = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, ciphertext, false)
    pkcs5unpad(decrypted_text)
  end

  defp pkcs5unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  # PKCS5Padding
  defp pkcs5padding(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<to_add>>, to_add)
  end
end
