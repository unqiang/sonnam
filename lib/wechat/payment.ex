defmodule Sonnam.WechatPay do
  @moduledoc """
  微信支付SDK
  """

  use GenServer
  require Logger

  import Sonnam.Utils.TimeUtil, only: [timestamp: 0]
  import Sonnam.Utils.CryptoUtil, only: [random_string: 1]

  @type method :: :get | :post | :put | :patch | :delete | :options | :head
  @type params :: map | keyword | [{binary, binary}] | any
  @type pem :: binary()
  @type serial_no :: String.t()

  @type payment_opts :: [
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

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  获取平台证书
  后续用 openssl x509 -in some_cert.pem -pubkey 导出平台公钥

  iex> get_certificates(__MODULE__)
  [
    %{
      "cert" => "-----BEGIN CERTIFICATE-----xxx-----END CERTIFICATE-----",
      "effective_time" => "2021-06-23T14:09:22+08:00",
      "expire_time" => "2026-06-22T14:09:22+08:00",
      "serial_no" => "35CE31ED8F4A50B930FF8D37C51B5ADA03265E7X"
    }
  ]
  """
  @spec get_certificates(pid()) :: [map()]
  def get_certificates(pid) do
    GenServer.call(pid, :get_certificates)
  end

  @spec decrypt_response(pid(), map()) :: binary()
  def decrypt_response(pid, data) do
    GenServer.call(pid, {:decrypt_response, data})
  end

  @spec verify_response(pid(), keyword(), binary()) :: boolean() | {:error, String.t()}
  def verify_response(pid, headers, body) do
    GenServer.call(pid, {:verify_response, headers, body})
  end

  @doc """
  Doc: https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_1_1.shtml

  ## Examples

  iex> create_jsapi_tranaction(:wechat, :wechat_pay,
      %{
        "out_trade_no" => "order_xxxx",
        "description" => "测试订单",
        "amount" => %{"total" => 1},
        "payer" => %{"openid" => "ohNY75Jw8MlsKuu4cFBbjmK4ZPxxx"}
      },
      recv_timeout: 2000)
  {:ok, %{"prepay_id" => "wx25104640294460668d258585313de91000"}}
  """
  @spec create_jsapi_transaction(pid(), map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def create_jsapi_transaction(pid, attrs, opts \\ []) do
    GenServer.call(pid, {:create_jsapi_transaction, attrs, opts})
  end

  @doc """

  Doc: https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_1.shtml

  ## Examples
  iex> create_native_transaction(
    :wechat_pay,
      %{
        "out_trade_no" => "order_1100",
        "description" => "测试订单",
        "amount" => %{"total" => 1}
      },
      recv_timeout: 2000
  )
  {:ok, %{"code_url" => "weixin://wxpay/bizpayurl?pr=A9ceSdqzk"}}
  """
  @spec create_native_transaction(pid(), map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def create_native_transaction(pid, attrs, opts \\ []) do
    GenServer.call(pid, {:create_native_transaction, attrs, opts})
  end

  @doc """
  生成小程序支付表单
  function description

  ## Examples

  iex> miniapp_payform(:wechat, "wx28094533993528b1d687203f4f48e20000")
  %{
    "appid" => "wxefd6b215fca0cacd",
    "nonceStr" => "ODnHX8RwAlw0",
    "package" => "prepay_id=wx28094533993528b1d687203f4f48e20000",
    "paySign" => "xxxx",
    "signType" => "RSA",
    "timeStamp" => 1624844734
  }
  """
  @spec miniapp_payform(pid(), String.t()) :: map()
  def miniapp_payform(pid, prepay_id) do
    GenServer.call(pid, {:miniapp_payform, prepay_id})
  end

  #
  # server part
  #

  def init(opts) do
    {:ok,
     %{
       appid: opts[:appid],
       mchid: opts[:mchid],
       notify_url: opts[:notify_url],
       apiv3_key: opts[:apiv3_key],
       wx_pubs: opts[:wx_pubs],
       client_serial_no: opts[:client_serial_no],
       client_key: load_pem(opts[:client_key]),
       client_cert: load_pem(opts[:client_cert])
     }}
  end

  def handle_call({:decrypt_response, data}, _, cfg) do
    {:reply, decrypt_data(cfg, data), cfg}
  end

  def handle_call({:verify_response, headers, body}, _, cfg) do
    {:reply, verify(cfg, headers, body), cfg}
  end

  def handle_call(:get_certificates, _, cfg) do
    with ua <- Enum.random(@user_agents),
         {:ok, %{"data" => data}} <-
           request(cfg, "/v3/certificates", :get, nil, %{}, [{"User-Agent", ua}]),
         res <-
           Enum.map(
             data,
             &%{
               "effective_time" => &1["effective_time"],
               "expire_time" => &1["expire_time"],
               "serial_no" => &1["serial_no"],
               "cert" => decrypt_data(cfg, &1["encrypt_certificate"])
             }
           ) do
      {:reply, res, cfg}
    end
  end

  def handle_call({:create_jsapi_transaction, attrs, opts}, _, cfg) do
    full_attrs =
      Map.merge(attrs, %{
        "appid" => cfg[:appid],
        "mchid" => cfg[:mchid],
        "notify_url" => cfg[:notify_url]
      })

    {:reply, request(cfg, "/v3/pay/transactions/jsapi", :post, nil, full_attrs, [], opts), cfg}
  end

  def handle_call({:create_native_transaction, attrs, opts}, _, cfg) do
    full_attrs =
      Map.merge(attrs, %{
        "appid" => cfg[:appid],
        "mchid" => cfg[:mchid],
        "notify_url" => cfg[:notify_url]
      })

    {:reply, request(cfg, "/v3/pay/transactions/native", :post, nil, full_attrs, [], opts), cfg}
  end

  def handle_call({:miniapp_payform, prepay_id}, _, cfg) do
    with ts <- timestamp(),
         nonce <- random_string(12),
         package <- "prepay_id=#{prepay_id}",
         sign <- sign_miniapp(cfg[:appid], ts, nonce, package, cfg[:client_key]) do
      {:reply,
       %{
         "appid" => cfg[:appid],
         "timeStamp" => ts,
         "nonceStr" => nonce,
         "package" => package,
         "signType" => "RSA",
         "paySign" => sign
       }, cfg}
    end
  end

  def handle_call({:get_transaction, transaction_id}, _, cfg) do
    {:reply,
     request(
       cfg,
       "/v3/pay/transactions/id/#{transaction_id}",
       :get,
       %{"mchid" => cfg[:mchid]},
       %{}
     ), cfg}
  end

  def handle_call({:close_transaction, out_trade_no}, _, cfg) do
    res =
      request(cfg, "/v3/pay/transactions/out-trade-no/#{out_trade_no}/close", :post, nil, %{
        "mchid" => cfg["mchid"]
      })

    {:reply, res, cfg}
  end

  def handle_call({:create_refund, attrs, opts}, _, cfg) do
    res = request(cfg, "/v3/refund/domestic/refunds", :post, nil, attrs, [], opts)
    {:reply, res, cfg}
  end

  # ------------- tool functions ----------------

  defp load_pem(pem) do
    [entry | _] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(entry)
  end

  defp gen_uri(api) do
    @service_host
    |> URI.merge(api)
    |> to_string()
  end

  @spec request(keyword(), String.t(), method(), map() | keyword() | nil, map(), list(), list()) ::
          {:ok, any()} | {:error, String.t()}
  defp request(cfg, api, method, params, attrs, headers \\ [], opts \\ [recv_timeout: 2000])

  defp request(cfg, api, method, params, attrs, headers, opts) do
    with ts <- timestamp(),
         nonce_str <- random_string(12),
         signature <- sign(method, api, attrs, nonce_str, ts, cfg[:client_key]),
         auth <-
           "mchid=\"#{cfg[:mchid]}\",nonce_str=\"#{nonce_str}\",timestamp=\"#{ts}\",serial_no=\"#{cfg[:client_serial_no]}\",signature=\"#{signature}\"",
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
           body: Jason.encode!(attrs),
           params: params,
           options: opts
         },
         {:ok, %HTTPoison.Response{body: body, status_code: 200, headers: headers}} <-
           HTTPoison.request(req),
         true <- verify(cfg, headers, body) do
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

  @spec verify(keyword(), [tuple()], binary()) ::
          boolean() | {:error, String.t()}
  def verify(cfg, headers, body) do
    with headers <-
           Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end),
         {_, wx_pub} <-
           Enum.find(cfg[:wx_pubs], fn {x, _} -> x == headers["wechatpay-serial"] end),
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

  @spec decrypt_data(keyword(), map()) :: String.t()
  defp decrypt_data(cfg, %{
         "algorithm" => "AEAD_AES_256_GCM",
         "associated_data" => aad,
         "ciphertext" => encoded_ciphertext,
         "nonce" => nonce
       }) do
    with apiv3_key <- cfg[:apiv3_key],
         {:ok, ciphertext} <- Base.decode64(encoded_ciphertext),
         size_total <- byte_size(ciphertext),
         ctext_len <- size_total - @tag_length,
         <<ctext::binary-size(ctext_len), tag::binary-size(@tag_length)>> <- ciphertext do
      :crypto.crypto_one_time_aead(:aes_256_gcm, apiv3_key, nonce, ctext, aad, tag, false)
    end
  end
end
