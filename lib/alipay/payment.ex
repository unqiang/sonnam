defmodule Sonnam.AliPayment do
  @moduledoc """
  支付宝sdk
  """

  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      import Sonnam.Utils.TimeUtil, only: [china_now: 0, datetime_to_str: 1]
      import Sonnam.Utils.CryptoUtil, only: [random_string: 1, sort_and_concat: 2]

      require Logger

      @type pem :: binary()
      @type err_t :: {:err, term()} | :error

      @type payment_cfg :: %{
              app_id: String.t(),
              sign_type: String.t(),
              notify_url: String.t(),
              private_key: String.t(),
              ali_publickey: String.t()
            }

      @type alipay_cli :: %{
              app_id: String.t(),
              sign_type: String.t(),
              notify_url: String.t(),
              private_key: pem(),
              ali_publickey: pem()
            }

      @type method :: :get | :post | :put | :patch | :delete | :options | :head

      @gateway "https://openapi.alipay.com/gateway.do"

      @spec config :: payment_cfg()
      def config,
        do:
          unquote(otp_app)
          |> Application.get_env(__MODULE__, [])

      defp get_cli() do
        cfg = config()

        %{
          app_id: cfg[:app_id],
          sign_type: cfg[:sign_type],
          notify_url: cfg[:notify_url],
          private_key: cfg[:private_key] |> load_pem(),
          ali_publickey: cfg[:ali_publickey] |> load_pem()
        }
      end

      defp load_pem(pem) do
        pem
        |> :public_key.pem_decode()
        |> List.first()
        |> :public_key.pem_entry_decode()
      end

      @doc """
      Doc: https://opendocs.alipay.com/open/02ivbs?scene=21

      ## Examples

      iex> biz = %{
        "out_trade_no" => "meta_test_12345",
        "total_amount" => "0.01",
        "subject" => "metatwo测试订单",
        "product_code" => "QUICK_WAP_WAY",
        "quit_url" => "http://www.taobao.com/product/113714.html"
      }
      iex> create_h5_transaction(biz)
      {:ok, "https://openapi.alipay.com/gateway.do?app_id..."}
      """
      def create_h5_transaction(params) do
        with cli <- get_cli() do
          gen_request(cli, "alipay.trade.wap.pay", %{"biz_content" => Jason.encode!(params)})
        end
      end

      @doc """
      Doc: https://opendocs.alipay.com/open/02ivbt
      ## Examples

      iex> query_transaction(%{"out_trade_no"=>"meta_test_12345})
      {:ok,
      %{
        "alipay_trade_query_response" => %{
          "buyer_logon_id" => "tt6***@126.com",
          "buyer_pay_amount" => "0.00",
          "buyer_user_id" => "2088202596034906",
          "code" => "10000",
          "invoice_amount" => "0.00",
          "msg" => "Success",
          "out_trade_no" => "meta_test_12345",
          "point_amount" => "0.00",
          "receipt_amount" => "0.00",
          "send_pay_date" => "2022-05-19 22:46:49",
          "total_amount" => "0.01",
          "trade_no" => "2022051922001434901424259398",
          "trade_status" => "TRADE_SUCCESS"
        },
        "sign" => "hvW44UThOVdIx1l9vuONtdoSP14ub7jRlVtLnC4vHWcIWzjor5j1G0qXVZEVWTJkf/zvapiZ3IM8tis6RAwlplTHupOJ9jFnrvKT4GQc6pQgMzEg4+g/vqNOvt5BjA4utIxCWBujhqW99raVIJfbpDUh1REMkxSMVlF+bZBdshKcmAPmba7u03+RgozkN2sRRcRbbOn+XwPDyI1Lz9nhmn8HlDfrwPcJDMvIpeOETbNivStLa9UEzzneHdXfHQCHcWFjB8JjWqPA/fJeOjxi6p0iEoESYTifPKQ189WIcjZmbWRXXC3BXZ0jae20dP7JV1IJeux7SHFyLklJQuTFLg=="
      }}
      """
      def query_transaction(params) do
        with cli <- get_cli() do
          do_request(cli, "alipay.trade.query", :post, %{}, %{
            "biz_content" => Jason.encode!(params)
          })
        end
      end

      # gen request for h5 payment
      defp gen_request(cli, api, payload) do
        with payload <-
               Map.merge(payload, %{
                 "app_id" => cli.app_id,
                 "method" => api,
                 "format" => "json",
                 "charset" => "utf-8",
                 "sign_type" => cli.sign_type,
                 "timestamp" => now_timestr(),
                 "version" => "1.0",
                 "notify_url" => cli.notify_url
               }),
             signature <- sign(cli, payload),
             payload <- Map.put(payload, "sign", signature) do
          {:ok, @gateway <> "?" <> URI.encode_query(payload)}
        end
      end

      @spec do_request(
              cli :: alipay_cli(),
              api :: String.t(),
              method :: method(),
              query :: %{String.t() => any()},
              payload :: %{String.t() => any()},
              headers :: [{String.t(), String.t()}],
              opts :: keyword()
            ) :: {:ok, %{String.t() => any()}} | err_t()
      defp do_request(
             cli,
             api,
             method,
             query,
             payload,
             headers \\ [],
             opts \\ [recv_timeout: 2000]
           )

      defp do_request(cli, api, method, _, payload, headers, opts) do
        with pub_query <- %{
               "app_id" => cli.app_id,
               "method" => api,
               "format" => "json",
               "charset" => "utf-8",
               "sign_type" => cli.sign_type,
               "timestamp" => now_timestr(),
               "version" => "1.0",
               "notify_url" => cli.notify_url
             },
             payload <- Map.merge(payload, pub_query),
             signature <- sign(cli, payload),
             payload <- Map.put(payload, "sign", signature),
             headers <- [
               {"Content-Type", "application/json"},
               {"Accept", "application/json"} | headers
             ],
             req <- %HTTPoison.Request{
               method: method,
               url: @gateway,
               headers: headers,
               params: payload,
               body: "",
               options: opts
             },
             {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.request(req),
             _ <-
               Logger.debug(%{
                 "msg" => "call alipay",
                 "api" => api,
                 "req" => payload,
                 "body" => body
               }),
             {:ok, resp} <- Jason.decode(body),
             true <- verify_request_sign(cli, body) do
          {:ok, resp}
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

      defp verify_request_sign(cli, body) do
        sign_type =
          cli.sign_type
          |> case do
            "RSA" -> :sha
            "RSA2" -> :sha256
          end

        regex = ~r/"(?<key>\w+_response)":(?<response>.*),"sign":/

        case Regex.named_captures(regex, body) do
          %{"response" => response, "key" => key} ->
            resp_json = Jason.decode!(body)
            signature = resp_json["sign"]
            :public_key.verify(response, sign_type, Base.decode64!(signature), cli.ali_publickey)

          nil ->
            {:error, "unexpected response data"}
        end
      end

      @spec verify_notify_sign(%{String.t() => any()}) :: boolean
      def verify_notify_sign(body) do
        cli = get_cli()
        {signature, body} = Map.pop(body, "sign")
        {ali_sign_type, body} = Map.pop(body, "sign_type")

        sign_type =
          ali_sign_type
          |> case do
            "RSA" -> :sha
            "RSA2" -> :sha256
          end

        string_to_sign = sort_and_concat(body, false)

        :public_key.verify(
          string_to_sign,
          sign_type,
          Base.decode64!(signature),
          cli.ali_publickey
        )
      end

      defp now_timestr() do
        {:ok, dt} = china_now()
        datetime_to_str(dt)
      end

      @spec sign(map(), %{String.t() => term()}) :: binary()
      defp sign(cli, attrs) do
        sign_type =
          cli.sign_type
          |> case do
            "RSA" -> :sha
            "RSA2" -> :sha256
          end

        attrs
        |> sort_and_concat(true)
        |> :public_key.sign(sign_type, cli.private_key)
        |> Base.encode64()
      end
    end
  end
end
