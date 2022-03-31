defmodule Sonnam.Wechat.Miniapp do
  @moduledoc """
  微信小程序工具

  Usage:

  ```
  defmodule MyAppA do
    use Sonnam.Wechat.Miniapp, otp_app: :myapp
  end

  defmodule MyAppB do

    IO.inspect(MyAppA.config())
  end
  ```
  """

  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      require Logger

      @type miniapp_cfg :: [app_id: String.t(), app_secret: String.t()]
      @type session_info :: %{openid: String.t(), session_key: String.t(), unionid: String.t()}
      @type err_t :: {:error, any()}

      @service_addr "https://api.weixin.qq.com"

      @spec config :: miniapp_cfg()
      def config,
        do:
          unquote(otp_app)
          |> Application.get_env(__MODULE__, [])

      # |> Keyword.merge(unquote(opts))

      defp process_response(%HTTPoison.Response{status_code: 200, body: body}),
        do: Jason.decode(body)

      defp process_response(%HTTPoison.Response{status_code: code}),
        do: {:error, "service #{code}"}

      # apply(__MODULE__, :get_miniapp_cfg, [])

      # ------------- real part ------------

      @doc """
      https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html
      """
      @spec get_access_token() ::
              {:ok, %{access_token: String.t(), expire_in: integer()}} | {:error, String.t()}
      def get_access_token() do
        with [app_id: app_id, app_secret: app_secret] <- config(),
             url <-
               "#{@service_addr}/cgi-bin/token?grant_type=client_credential&appid=#{app_id}&secret=#{app_secret}",
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

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/login/auth.code2Session.html
      """
      @spec get_session(String.t()) :: {:ok, session_info()} | {:error, String.t()}
      def get_session(code) do
        with [app_id: app_id, app_secret: app_secret] <- config(),
             url <-
               "#{@service_addr}/sns/jscode2session?appid=#{app_id}&secret=#{app_secret}&js_code=#{code}&grant_type=authorization_code",
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

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/qr-code/wxacode.getUnlimited.html
      """
      @spec get_unlimited_wxacode(String.t(), keyword()) :: {:ok, iodata()} | {:error, String.t()}
      def get_unlimited_wxacode(token, opts) do
        with url <- "#{@service_addr}/wxa/getwxacodeunlimit?access_token=#{token}",
             payload <- %{
               scene: Keyword.get(opts, :scene),
               page: Keyword.get(opts, :page),
               width: Keyword.get(opts, :width),
               auto_color: Keyword.get(opts, :auto_color),
               line_color: Keyword.get(opts, :line_color),
               is_hyaline: Keyword.get(opts, :hyaline)
             },
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body),
             %HTTPoison.Response{status_code: 200, body: image} <- response do
          {:ok, image}
        else
          reason ->
            Logger.error("get_unlimited_wxacode error: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/url-link/urllink.generate.html
      """
      @spec get_urllink(String.t(), keyword()) :: {:ok, map()} | err_t()
      def get_urllink(token, opts) do
        with url <- "#{@service_addr}/wxa/generate_urllink?access_token=#{token}",
             payload <- %{
               path: Keyword.get(opts, :path),
               query: Keyword.get(opts, :query),
               env_version: Keyword.get(opts, :env_version),
               is_expire: Keyword.get(opts, :is_expire),
               expire_type: Keyword.get(opts, :expire_type),
               expire_time: Keyword.get(opts, :expire_time),
               expire_interval: Keyword.get(opts, :expire_interval)
             },
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body) do
          process_response(response)
        else
          reason ->
            Logger.error("get_urllink error: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/subscribe-message/subscribeMessage.send.html
      """
      @spec subscribe_send(String.t(), String.t(), String.t(), %{atom() => any()}, keyword()) ::
              {:ok, term()} | err_t()
      def subscribe_send(token, touser, template_id, data, opts) do
        with url <- "#{@service_addr}/cgi-bin/message/subscribe/send?access_token=#{token}",
             payload <- %{
               touser: touser,
               template_id: template_id,
               data: data,
               page: Keyword.get(opts, :page),
               miniprogram_state: Keyword.get(opts, :miniprogram_state),
               lang: Keyword.get(opts, :lang)
             },
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body) do
          process_response(response)
        else
          reason ->
            Logger.error("send subscribe message failed: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/sec-check/security.msgSecCheck.html
      """
      @spec msg_sec_check(String.t(), String.t(), integer, String.t()) :: {:ok, term()} | err_t()
      def msg_sec_check(token, openid, scene, content) do
        with url <- "#{@service_addr}/wxa/msg_sec_check?access_token=#{token}",
             payload <- %{
               version: 2,
               openid: openid,
               scene: scene,
               content: content
             },
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body) do
          process_response(response)
        else
          reason ->
            Logger.error("send subscribe message failed: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/uniform-message/uniformMessage.send.html
      """
      @spec uniform_send(String.t(), String.t(), String.t(), %{String.t() => any()},
              mp_appid: String.t(),
              mini_appid: String.t()
            ) :: {:ok, term()} | err_t()
      def uniform_send(token, touser, template_id, data, opt) do
        with url <-
               "#{@service_addr}/cgi-bin/message/wxopen/template/uniform_send?access_token=#{token}",
             payload <- %{
               "touser" => touser,
               "mp_template_msg" => %{
                 "appid" => opt[:mp_appid],
                 "template_id" => template_id,
                 "url" => "",
                 "miniprogram" => %{"appid" => opt[:mini_appid], "path" => "index"},
                 "data" => data
               }
             },
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body) do
          process_response(response)
        else
          reason ->
            Logger.error("send uniform msg failed: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/phonenumber/phonenumber.getPhoneNumber.html
      """
      @spec get_phonenumber(String.t(), String.t()) :: {:ok, term()} | err_t()
      def get_phonenumber(token, code) do
        with url <- "#{@service_addr}/wxa/business/getuserphonenumber?access_token=#{token}",
             payload <- %{"code" => code},
             {:ok, body} <- Jason.encode(payload),
             {:ok, response} <- HTTPoison.post(url, body) do
          process_response(response)
        else
          reason ->
            Logger.error("get phonenumber failed: #{inspect(reason)}")
            {:error, "Internal server error"}
        end
      end
    end
  end
end
