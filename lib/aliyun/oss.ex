defmodule Sonnam.Aliyun.Oss do
  @moduledoc """
  阿里云OSS token生成
  """
  import Sonnam.Aliyun.OssConfig

  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

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
      |> Sonnam.Aliyun.Sign.sign(access_key_secret())

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
