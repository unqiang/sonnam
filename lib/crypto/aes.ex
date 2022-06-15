defmodule Sonnam.Crypto.AES do
  @moduledoc false
  @block_size 16

  @type key :: <<_::16>>

  @spec encrypt(key(), binary) :: binary
  def encrypt(secret_key, plaintext) do
    # iv = :crypto.strong_rand_bytes(16)
    iv = secret_key
    plaintext = pkcs5padding(plaintext, @block_size)
    encrypted_text = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, plaintext, true)
    Base.encode64(encrypted_text)
  end

  @spec decrypt(key(), binary) :: binary
  def decrypt(secret_key, ciphertext) do
    {:ok, ciphertext} = Base.decode64(ciphertext)
    <<iv::binary-16, ciphertext::binary>> = ciphertext
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
