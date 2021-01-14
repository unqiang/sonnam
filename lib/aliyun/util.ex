defmodule Sonnam.Aliyun.OssConfig do
  [:endpoint, :access_key_id, :access_key_secret]
  |> Enum.map(fn config ->
    def unquote(config)() do
      :aliyun_oss
      |> Application.get_env(unquote(config))
      |> Confex.Resolver.resolve!()
    end
  end)
end

defmodule Sonnam.Aliyun.Sign do
  @moduledoc """
  签名工具
  """

  @doc """
  签名字符串
  """
  @spec sign(String.t(), String.t()) :: String.t()
  def sign(string_to_sign, key) do
    :crypto.hmac(:sha, key, string_to_sign)
    |> Base.encode64()
  end
end
