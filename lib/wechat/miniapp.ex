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

      defp process_response(%HTTPoison.Response{status_code: 200, body: body}),
        do: Jason.decode(body)

      defp process_response(%HTTPoison.Response{status_code: code}),
        do: {:error, "service #{code}"}

      @doc """
      https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html
      """
      @spec get_access_token() ::
              {:ok, %{access_token: String.t(), expire_in: integer()}} | {:error, String.t()}
      @deprecated "Use get_access_token_v2 instead"
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
      https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html
      """
      @spec get_access_token_v2() ::
              {:ok, map()} | {:error, String.t()}
      def get_access_token_v2() do
        with [app_id: app_id, app_secret: app_secret] <- config(),
             {:ok, res} <-
               do_req(:get, "/cgi-bin/token", "", "", %{
                 "grant_type" => "client_credential",
                 "appid" => app_id,
                 "secret" => app_secret
               }) do
          Jason.decode(res)
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/login/auth.code2Session.html
      """
      @deprecated "use get_session_v2/1 instead"
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
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/login/auth.code2Session.html
      """
      @spec get_session_v2(String.t()) :: {:ok, map()} | err_t()
      def get_session_v2(code) do
        with [app_id: app_id, app_secret: app_secret] <- config(),
             {:ok, res} <-
               do_req(:get, "/sns/jscode2session", "", "", %{
                 "appid" => app_id,
                 "secret" => app_secret,
                 "js_code" => code,
                 "grant_type" => "authorization_code"
               }) do
          Jason.decode(res)
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/qr-code/wxacode.getUnlimited.html
      """
      @spec get_unlimited_wxacode(String.t(), %{String.t() => any()}) ::
              {:ok, iodata()} | {:error, String.t()}
      def get_unlimited_wxacode(token, payload) do
        with {:ok, body} <- Jason.encode(payload),
             do: do_req(:post, "/wxa/getwxacodeunlimit", token, body)
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/url-link/urllink.generate.html
      """
      @spec get_urllink(String.t(), %{String.t() => any()}) :: {:ok, map()} | err_t()
      def get_urllink(token, payload) do
        with {:ok, body} <- Jason.encode(payload),
             {:ok, res} <- do_req(:post, "/wxa/generate_urllink", token, body) do
          Jason.decode(res)
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/url-scheme/urlscheme.generate.html
      """
      @spec generate_scheme(token :: String.t(), payload :: %{String.t() => any()}) ::
              {:ok, map()} | err_t()
      def generate_scheme(token, payload) do
        with {:ok, body} <- Jason.encode(payload),
             {:ok, res} <- do_req(:post, "/wxa/generatescheme", token, body) do
          Jason.decode(res)
        end
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/subscribe-message/subscribeMessage.send.html
      """
      @spec subscribe_send(String.t(), String.t(), String.t(), %{atom() => any()}, keyword()) ::
              {:ok, term()} | err_t()
      @deprecated "use subscribe_send_v2/0 instead"
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
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/subscribe-message/subscribeMessage.send.html
      """
      @spec subscribe_send_v2(String.t(), %{String.t() => any()}) ::
              {:ok, term()} | err_t()
      def subscribe_send_v2(token, payload) do
        with {:ok, body} <- Jason.encode(payload),
             {:ok, res} <- do_req(:post, "/cgi-bin/message/subscribe/send", token, body) do
          Jason.decode(res)
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
      @deprecated "use uniform_send/2 instead"
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
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/uniform-message/uniformMessage.send.html
      """
      @spec uniform_send_v2(String.t(), %{String.t() => any()}) :: {:ok, term()} | err_t()
      def uniform_send_v2(token, payload) do
        with {:ok, body} <- Jason.encode(payload),
             {:ok, res} <-
               do_req(:post, "/cgi-bin/message/wxopen/template/uniform_send", token, body),
             do: Jason.decode(res)
      end

      @doc """
      https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/phonenumber/phonenumber.getPhoneNumber.html
      """
      @spec get_phonenumber(String.t(), String.t()) :: {:ok, term()} | err_t()
      def get_phonenumber(token, code) do
        with {:ok, body} <- Jason.encode(%{"code" => code}),
             {:ok, res} <- do_req(:post, "/wxa/business/getuserphonenumber", token, body),
             do: Jason.decode(res)
      end

      @spec do_req(
              atom(),
              String.t(),
              String.t(),
              binary,
              %{String.t() => any()},
              keyword()
            ) :: {:ok, iodata()} | err_t()
      defp do_req(method, api, token, body, query \\ %{}, opts \\ [recv_timeout: 2000])

      defp do_req(method, api, token, body, query, opts) do
        with url <- gen_uri(api),
             params <- Map.merge(query, %{"access_token" => token}),
             req <- %HTTPoison.Request{
               method: method,
               url: url,
               headers: [{"Content-Type", "application/json"}],
               body: body,
               params: params,
               options: opts
             },
             _ <- Logger.debug("call wx #{api} with req: #{body}"),
             {:ok, %HTTPoison.Response{body: body, status_code: 200}} <-
               HTTPoison.request(req) do
          {:ok, body}
        else
          {:ok, %HTTPoison.Response{body: body}} ->
            {:error, body}

          {:error, error} ->
            Logger.error("#{inspect(error)}")
            {:error, "Interal server error"}

          other_error ->
            Logger.error("#{inspect(other_error)}")
            {:error, "Interal server error"}
        end
      end

      defp gen_uri(api) do
        @service_addr
        |> URI.merge(api)
        |> to_string()
      end
    end
  end
end
