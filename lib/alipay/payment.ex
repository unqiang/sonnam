defmodule Sonnam.AliPayment do
  @moduledoc """
  支付宝sdk
  """

  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      import Sonnam.Utils.TimeUtil, only: [china_now: 0, datetime_to_str: 2]
      import Sonnam.Utils.CryptoUtil, only: [random_string: 1, sort_and_concat: 2]

      require Logger

      @type pem :: binary()
      @type err_t :: {:err, term()} | :error

      @type payment_cfg :: %{
              app_id: String.t(),
              sign_type: String.t(),
              notify_url: String.t(),
              seller_id: String.t(),
              private_key: String.t(),
              ali_pubkey: String.t()
            }

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
          seller_id: cfg[:seller_id],
          private_key: cfg[:private_key] |> load_pem(),
          ali_pubkey: cfg[:ali_pubkey] |> load_pem()
        }
      end

      defp load_pem(pem) do
        pem
        |> :public_key.pem_decode()
        |> List.first()
        |> :public_key.pem_entry_decode()
      end

      def precreate(params) do
        with cli <- get_cli() do
          do_request(cli, "alipay.trade.precreate", :post, params)
        end
      end

      @spec do_request(
              map(),
              String.t(),
              method(),
              %{String.t() => any()},
              %{String.t() => any()},
              [tuple],
              keyword()
            ) :: {:ok, map()} | err_t()
      defp do_request(
             cli,
             api,
             method,
             query,
             params,
             headers \\ [],
             opts \\ [recv_timeout: 2000]
           )

      defp do_request(cli, api, method, query, params, headers, opts) do
        with params <-
               Map.merge(params, %{
                 "app_id" => cli.app_id,
                 "method" => method,
                 "format" => "JSON",
                 "charset" => "utf-8",
                 "sign_type" => cli.sign_type,
                 "timestamp" => now_timestr(),
                 "version" => "1.0",
                 "notify_url" => cli.notify_url
               }),
             signature <- sign(cli, params),
             params <- Map.put(params, "sign", signature),
             headers <- [
               {"Content-Type", "application/json"},
               {"Accept", "application/json"} | headers
             ],
             req <- %HTTPoison.Request{
               method: method,
               url: @gateway,
               headers: headers,
               params: query,
               body: Jason.encode!(params),
               options: opts
             },
             {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.request(req) do
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

      defp now_timestr() do
        china_now()
        |> datetime_to_str()
      end

      @spec sign(map(), %{String.t() => term()}) :: binary()
      defp sign(cli, attrs) do
        string2sign = sort_and_concat(attrs)

        sign_type =
          cli.sign_type
          |> case do
            "RSA" -> :sha
            "RSA2" -> :sha256
          end

        string_to_sign
        |> :public_key.sign(sign_type, client_key)
        |> Base.encode64()
      end
    end
  end
end
