defmodule Sonnam.AliyunOss.Token do
  @moduledoc """
  阿里云OSS token生成
  """
  import Sonnam.AliyunOss.Util, only: [sign: 2]

  @type oss_cfg :: [
          bucket: String.t(),
          endpoint: String.t(),
          access_key_id: String.t(),
          access_key_secret: String.t()
        ]

  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

  @spec get_token(
          oss_cfg(),
          String.t(),
          integer(),
          String.t()
        ) :: {:ok, String.t()}
  def get_token(cfg, upload_dir, expire_sec, callback) do
    [
      bucket: bucket,
      endpoint: endpoint,
      access_key_id: access_key_id,
      access_key_secret: access_key_secret
    ] = cfg

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
      |> sign(access_key_secret)

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
      "accessid" => access_key_id,
      "host" => "https://#{bucket}.#{endpoint}",
      "policy" => policy,
      "signature" => signature,
      "expire" => DateTime.to_unix(expire),
      "dir" => upload_dir,
      "callback" => base64_callback_body
    }
    |> Jason.encode()
  end
end
