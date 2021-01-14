defmodule Sonnam.Wechat.MiniappConfig do
  [:app_id, :app_secret]
  |> Enum.map(fn config ->
    def unquote(config)() do
      :wechat_miniapp
      |> Application.get_env(unquote(config))
      |> Confex.Resolver.resolve!()
    end
  end)
end

defmodule Sonnam.Wechat.Miniapp do
  @moduledoc """
  微信小程序工具
  """
  require Logger
  require Sonnam.Wechat.MiniappConfig

  @service_addr "https://api.weixin.qq.com"

  def get_session(code) do
    with app_id <- Sonnam.Wechat.MiniappConfig.app_id(),
         app_secret <- Sonnam.Wechat.MiniappConfig.app_secret(),
         url <-
           "#{@service_addr}/sns/jscode2session?appid=#{app_id}&secret=#{app_secret}&js_code=#{
             code
           }&grant_type=authorization_code",
         {:ok, response} <- HTTPoison.get(url, recv_timeout: 3) do
      response |> process_response()
    else
      err ->
        Logger.error(inspect(err))
        {:error, inspect(err)}
    end
  end

  def get_access_token() do
    with app_id <- Sonnam.Wechat.MiniappConfig.app_id(),
         app_secret <- Sonnam.Wechat.MiniappConfig.app_secret(),
         url <-
           "#{@service_addr}/cgi-bin/token?grant_type=client_credential&appid=#{app_id}&secret=#{
             app_secret
           }",
         {:ok, response} <- HTTPoison.get(url, recv_timeout: 3) do
      response |> process_response()
    else
      err ->
        Logger.error(inspect(err))
        {:error, inspect(err)}
    end
  end

  defp process_response(%HTTPoison.Response{status_code: 200, body: body}), do: Jason.decode(body)
  defp process_response(%HTTPoison.Response{status_code: code}), do: {:error, "service #{code}"}
end
