defmodule Sonnam.WechatPayV2 do
  @moduledoc false

  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      import Sonnam.Utils.TimeUtil, only: [timestamp: 0]
      import Sonnam.Utils.CryptoUtil, only: [random_string: 1]

      require Logger

      @type method :: :get | :post | :put | :patch | :delete | :options | :head
      @type params :: map | keyword | [{binary, binary}] | any
      @type pem :: binary()
      @type serial_no :: String.t()
      @type err_t :: {:err, term()} | :error

      @type payment_cfg :: [
              appid: String.t(),
              mchid: String.t(),
              notify_url: String.t(),
              apiv3_key: binary(),
              # 微信平台证书列表
              wx_pubs: [{serial_no(), pem()}],
              # 商户证书序列号
              client_serial_no: serial_no(),
              # 商户私钥
              client_key: pem(),
              # 商户证书
              client_cert: pem()
            ]

      @service_host "https://api.mch.weixin.qq.com"
      @tag_length 16
      @user_agents [
        "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5",
        "Mozilla/5.0 (Linux; U; Android 2.2.1; zh-cn; HTC_Wildfire_A3333 Build/FRG83D) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1",
        "Mozilla/5.0 (Linux; U; Android 2.3.7; en-us; Nexus One Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1"
      ]

      @spec config :: payment_cfg()
      def config,
        do:
          unquote(otp_app)
          |> Application.get_env(__MODULE__, [])

      defp get_client() do
        cfg = config()

        %{
          appid: cfg[:appid],
          mchid: cfg[:mchid],
          notify_url: cfg[:notify_url],
          apiv3_key: cfg[:apiv3_key],
          wx_pubs: cfg[:wx_pubs],
          client_serial_no: cfg[:client_serial_no],
          client_key: load_pem(cfg[:client_key]),
          client_cert: load_pem(cfg[:client_cert])
        }
      end

      defp load_pem(pem) do
        pem
        |> :public_key.pem_decode()
        |> List.first()
        |> :public_key.pem_entry_decode()
      end

      defp gen_uri(api) do
        @service_host
        |> URI.merge(api)
        |> to_string()
      end

      @spec decrypt_response(map()) :: {:ok, binary()} | err_t()
      def decrypt_response(data) do
        get_client()
        |> decrypt_data(data)
      end

      @doc """
      获取平台证书
      后续用 openssl x509 -in some_cert.pem -pubkey 导出平台公钥

      iex> get_certificates()
      {
        :ok,
        [
          %{
            "cert" => "-----BEGIN CERTIFICATE-----xxx-----END CERTIFICATE-----",
            "effective_time" => "2021-06-23T14:09:22+08:00",
            "expire_time" => "2026-06-22T14:09:22+08:00",
            "serial_no" => "35CE31ED8F4A50B930FF8D37C51B5ADA03265E7X"
          }
        ]
      }
      """
      @spec get_certificates() :: {:ok, [map()]} | err_t()
      def get_certificates() do
        with ua <- Enum.random(@user_agents),
             cli <- get_client(),
             {:ok, %{"data" => data}} <-
               request(cli, "/v3/certificates", :get, nil, %{}, [{"User-Agent", ua}]),
             res <-
               Enum.map(
                 data,
                 &%{
                   "effective_time" => &1["effective_time"],
                   "expire_time" => &1["expire_time"],
                   "serial_no" => &1["serial_no"],
                   "cert" => decrypt_data!(cli, &1["encrypt_certificate"])
                 }
               ) do
          {:ok, res}
        end
      end

      @spec verify_response([tuple], binary) :: boolean() | err_t()
      def verify_response(headers, body) do
        with cli <- get_client(), do: verify(cli, headers, body)
      end

      @doc """
      Doc: https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_1_1.shtml

      ## Examples

      iex> create_jsapi_tranaction(
          %{
            "out_trade_no" => "order_xxxx",
            "description" => "测试订单",
            "amount" => %{"total" => 1},
            "payer" => %{"openid" => "ohNY75Jw8MlsKuu4cFBbjmK4ZPxxx"}
          },
          recv_timeout: 2000)
      {:ok, %{"prepay_id" => "wx25104640294460668d258585313de91000"}}
      """
      @spec create_jsapi_transaction(map(), keyword()) :: {:ok, term()} | err_t()
      def create_jsapi_transaction(params, opts \\ []) do
        with cli <- get_client(),
             params <-
               Map.merge(params, %{
                 "appid" => cli[:appid],
                 "mchid" => cli[:mchid],
                 "notify_url" => cli[:notify_url]
               }) do
          request(cli, "/v3/pay/transactions/jsapi", :post, nil, params, [], opts)
        end
      end

      @doc """

      Doc: https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_1.shtml

      ## Examples
      iex> create_native_transaction(
          %{
            "out_trade_no" => "order_1100",
            "description" => "测试订单",
            "amount" => %{"total" => 1}
          },
          recv_timeout: 2000
      )
      {:ok, %{"code_url" => "weixin://wxpay/bizpayurl?pr=A9ceSdqzk"}}
      """
      @spec create_native_transaction(map(), keyword()) :: {:ok, map()} | err_t()
      def create_native_transaction(params, opts \\ []) do
        with cli <- get_client(),
             params <-
               Map.merge(params, %{
                 "appid" => cli[:appid],
                 "mchid" => cli[:mchid],
                 "notify_url" => cli[:notify_url]
               }) do
          request(cli, "/v3/pay/transactions/native", :post, nil, params, [], opts)
        end
      end

      @doc """
      Doc: https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_9.shtml

      ## Examples

      iex> create_refund(
        %{
          "out_trade_no" => "order_xxxx",
          "out_refund_no" => "refund_xxxx",
          "reason" => "退款",
          "amount" => %{
            "refund" => 1,
            "total" => 1,
            "currency" => "CNY"
          }
        },
        recv_timeout: 2000
      )
      {:ok, return_value}
      """
      @spec create_refund(map(), keyword()) :: {:ok, map()} | err_t()
      def create_refund(params, opts \\ []) do
        with cli <- get_client() do
          request(cli, "/v3/refund/domestic/refunds", :post, nil, params, [], opts)
        end
      end

      @doc """
      生成小程序支付表单
      function description

      ## Examples

      iex> miniapp_payform("wx28094533993528b1d687203f4f48e20000")
      %{
        "appid" => "wxefd6b215fca0cacd",
        "nonceStr" => "ODnHX8RwAlw0",
        "package" => "prepay_id=wx28094533993528b1d687203f4f48e20000",
        "paySign" => "xxxx",
        "signType" => "RSA",
        "timeStamp" => 1624844734
      }
      """
      @spec miniapp_payform(String.t()) :: map()
      def miniapp_payform(prepay_id) do
        with cli <- get_client(),
             ts <- timestamp(),
             nonce <- random_string(12),
             package <- "prepay_id=#{prepay_id}",
             sign <- sign_miniapp(cli[:appid], ts, nonce, package, cli[:client_key]) do
          %{
            "appid" => cli[:appid],
            "timeStamp" => ts,
            "nonceStr" => nonce,
            "package" => package,
            "signType" => "RSA",
            "paySign" => sign
          }
        end
      end

      @spec request(
              map(),
              String.t(),
              method(),
              map() | keyword() | nil,
              map(),
              list(),
              list()
            ) ::
              {:ok, any()} | err_t()
      defp request(cli, api, method, query, params, headers \\ [], opts \\ [recv_timeout: 2000])

      defp request(cli, api, method, query, params, headers, opts) do
        with ts <- timestamp(),
             nonce_str <- random_string(12),
             signature <- sign(method, api, params, nonce_str, ts, cli[:client_key]),
             auth <-
               "mchid=\"#{cli[:mchid]}\",nonce_str=\"#{nonce_str}\",timestamp=\"#{ts}\",serial_no=\"#{cli[:client_serial_no]}\",signature=\"#{signature}\"",
             full_headers <- [
               {"Content-Type", "application/json"},
               {"Accept", "application/json"},
               {"Authorization", "WECHATPAY2-SHA256-RSA2048 " <> auth}
               | headers
             ],
             req <- %HTTPoison.Request{
               method: method,
               url: gen_uri(api),
               headers: full_headers,
               body: Jason.encode!(params),
               params: query,
               options: opts
             },
             {:ok, %HTTPoison.Response{body: body, status_code: 200, headers: headers}} <-
               HTTPoison.request(req),
             true <- verify(cli, headers, body) do
          Jason.decode(body)
        else
          {:ok, %HTTPoison.Response{body: body}} ->
            {:error, body}

          {:error, msg} ->
            {:error, msg}

          other_error ->
            Logger.error("#{inspect(other_error)}")
            {:error, "Interal server error"}
        end
      end

      defp sign(method, api, attrs, nonce_str, timestamp, client_key) do
        {http_method, body} =
          case method do
            :post -> {"POST", Jason.encode!(attrs)}
            :get -> {"GET", ""}
          end

        string_to_sign = "#{http_method}\n#{api}\n#{timestamp}\n#{nonce_str}\n#{body}\n"

        Logger.debug("string to sign => #{string_to_sign}")

        string_to_sign
        |> :public_key.sign(:sha256, client_key)
        |> Base.encode64()
      end

      defp sign_miniapp(appid, ts, nonce, package, client_key) do
        string_to_sign = "#{appid}\n#{ts}\n#{nonce}\n#{package}\n"

        Logger.debug("string to sign => #{string_to_sign}")

        string_to_sign
        |> :public_key.sign(:sha256, client_key)
        |> Base.encode64()
      end

      @spec verify(map(), [tuple()], binary()) :: boolean() | err_t()
      def verify(cli, headers, body) do
        with headers <-
               Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end),
             {_, wx_pub} <-
               Enum.find(cli[:wx_pubs], fn {x, _} -> x == headers["wechatpay-serial"] end),
             wx_pub_key <- load_pem(wx_pub),
             ts <- headers["wechatpay-timestamp"],
             nonce <- headers["wechatpay-nonce"],
             string_to_sign <- "#{ts}\n#{nonce}\n#{body}\n",
             encoded_wx_signature <- headers["wechatpay-signature"],
             {:ok, wx_signature} <- Base.decode64(encoded_wx_signature) do
          :public_key.verify(string_to_sign, :sha256, wx_signature, wx_pub_key)
        else
          reason ->
            Logger.error("#{inspect(reason)}")
            {:error, "wechat response verify error"}
        end
      end

      @spec decrypt_data(map(), map()) :: {:ok, binary} | err_t()
      defp decrypt_data(cli, %{
             "algorithm" => "AEAD_AES_256_GCM",
             "associated_data" => aad,
             "ciphertext" => encoded_ciphertext,
             "nonce" => nonce
           }) do
        with apiv3_key <- cli[:apiv3_key],
             {:ok, ciphertext} <- Base.decode64(encoded_ciphertext),
             size_total <- byte_size(ciphertext),
             ctext_len <- size_total - @tag_length,
             <<ctext::binary-size(ctext_len), tag::binary-size(@tag_length)>> <- ciphertext,
             ret <-
               :crypto.crypto_one_time_aead(
                 :aes_256_gcm,
                 apiv3_key,
                 nonce,
                 ctext,
                 aad,
                 tag,
                 false
               ) do
          {:ok, ret}
        end
      end

      defp decrypt_data(_cli, _data), do: {:error, "invalida data form"}

      defp decrypt_data!(cli, map) do
        decrypt_data(cli, map)
        |> case do
          {:ok, ret} -> ret
          err -> err
        end
      end
    end
  end
end
