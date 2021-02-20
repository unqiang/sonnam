defmodule Sonnam.Wechat.Miniapp do
  @moduledoc """
  微信小程序工具
  """
  require Logger

  @type miniapp_cfg :: [app_id: String.t(), app_secret: String.t()]
  @type session_info :: %{openid: String.t(), session_key: String.t(), unionid: String.t()}

  @service_addr "https://api.weixin.qq.com"

  @spec get_session(miniapp_cfg(), String.t()) :: {:ok, session_info()} | {:error, String.t()}
  def get_session(cfg, code) do
    with [app_id: app_id, app_secret: app_secret] <- cfg,
         url <-
           "#{@service_addr}/sns/jscode2session?appid=#{app_id}&secret=#{app_secret}&js_code=#{
             code
           }&grant_type=authorization_code",
         {:ok, response} <- HTTPoison.get(url, recv_timeout: 3),
         {:ok, reply} <- process_response(response) do
      case reply do
        %{"errcode" => _, "errmsg" => msg} ->
          {:error, msg}

        _ ->
          {:ok,
           %{
             openid: Map.get(reply, "openid"),
             session_key: Map.get(reply, "session_key"),
             unionid: Map.get(reply, "unionid", "")
           }}
      end
    else
      err ->
        Logger.error("wechatmini jscode2session failed: #{inspect(err)}")
        {:error, inspect(err)}
    end
  end

  @spec get_access_token(miniapp_cfg()) ::
          {:ok, %{access_token: String.t(), expire_in: integer()}} | {:error, String.t()}
  def get_access_token(cfg) do
    with [app_id: app_id, app_secret: app_secret] <- cfg,
         url <-
           "#{@service_addr}/cgi-bin/token?grant_type=client_credential&appid=#{app_id}&secret=#{
             app_secret
           }",
         {:ok, response} <- HTTPoison.get(url, recv_timeout: 3) do
      response
      |> process_response()
      |> (fn
            {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
              {:ok, %{access_token: token, expire_in: expires_in}}

            {:ok, %{"errorcode" => code, "errormsg" => msg}} ->
              {:error, "#{code}:#{msg}"}
          end).()
    else
      err ->
        Logger.error("wechatmini get token failed: #{inspect(err)}")
        {:error, inspect(err)}
    end
  end

  defp process_response(%HTTPoison.Response{status_code: 200, body: body}), do: Jason.decode(body)
  defp process_response(%HTTPoison.Response{status_code: code}), do: {:error, "service #{code}"}
end
