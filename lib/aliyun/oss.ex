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

defmodule Sonnam.Aliyun.Oss do
  @moduledoc """
  阿里云OSS token生成
  """
  import Sonnam.Aliyun.OssConfig

  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

  @spec sign(String.t(), String.t()) :: String.t()
  defp sign(string_to_sign, key) do
    :crypto.hmac(:sha, key, string_to_sign)
    |> Base.encode64()
  end


  def get_token(bucket, upload_dir, expire_sec, callback) do
    expire =
      DateTime.now!("Etc/UTC")
      |> DateTime.add(expire_sec, :second)

    policy =
      %{
        "expiration" => DateTime.to_iso8601(expire),
        "conditions" => [["starts-with", "$key", upload_dir]]
      }
      |> Jason.encode!()
      |> String.trim()
      |> Base.encode64()

    signature =
      policy
      |> sign(access_key_secret())

    base64_callback_body =
      %{
        "callbackUrl" => callback,
        "callbackBody" => @callback_body,
        "callbackBodyType" => "application/x-www-form-urlencoded"
      }
      |> Jason.encode!()
      |> String.trim()
      |> Base.encode64()

    %{
      "accessid" => access_key_id(),
      "host" => "http://#{bucket}.#{endpoint()}",
      "policy" => policy,
      "signature" => signature,
      "expire" => DateTime.to_unix(expire),
      "dir" => upload_dir,
      "callback" => base64_callback_body
    }
    |> Jason.encode()
  end
end
