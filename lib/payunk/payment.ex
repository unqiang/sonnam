defmodule Sonnam.UnkPayment do
  @moduledoc """
  unk sdk
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
              appid: String.t(),
              appkey: String.t(),
              notify_url: String.t()
            }

      @type unk_cli :: %{
              appid: String.t(),
              appkey: String.t(),
              notify_url: String.t()
            }

      @type method :: :get | :post | :put | :patch | :delete | :options | :head

      @gateway "https://api.payunk.com/index/unifiedorder"

      @spec config :: payment_cfg()
      def config,
        do:
          unquote(otp_app)
          |> Application.get_env(__MODULE__, [])

      defp get_cli() do
        cfg = config()

        %{
          appid: cfg[:appid],
          appkey: cfg[:appkey],
          notify_url: cfg[:notify_url]
        }
      end

      @doc """
      Doc: https://cl.payunk.com/user/channel/word.html?id=27

      ## Examples

      iex> biz = {
        "amount" => 0.01,
        "out_trade_no" => "metatest01",
        "success_url" => "https://baidu.com",
        "error_url" => "https://baidu.com",
        "extend" => Jason.encode!(%{"body" => "商品描述"})
      }
      iex> create_h5_transaction(biz)
      {:ok, _}
      """
      def create_h5_transaction(params) do
        with cli <- get_cli() do
          do_request(cli, :post, Map.put(params, "pay_type", "partnerJs"))
        end
      end

      # gen request form for h5 payment
      # defp gen_request_form(cli, payload) do
      #   with payload <-
      #          Map.merge(payload, %{
      #            "version" => "v1.0",
      #            "appid" => cli.appid,
      #            "callback_url" => cli.notify_url
      #          }),
      #        signature <- sign(cli, payload),
      #        payload <- Map.put(payload, "sign", signature),
      #        _ <-
      #          Logger.debug(%{
      #            "msg" => "call unkpay",
      #            "req" => payload
      #          }) do
      #     {:ok, payload}
      #   end
      # end

      defp do_request(cli, method, payload) do
        with payload <-
               Map.merge(payload, %{
                 "version" => "v1.0",
                 "appid" => cli.appid,
                 "callback_url" => cli.notify_url
               }),
             signature <- sign(cli, payload),
             payload <- Map.put(payload, "sign", signature),
             req <- %HTTPoison.Request{
               method: method,
               url: @gateway,
               headers: [{"Content-Type", "application/json"}],
               params: %{"format" => "json"},
               body: Jason.encode!(payload),
               options: [recv_timeout: 2000]
             },
             {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.request(req),
             _ <-
               Logger.debug(%{
                 "msg" => "call unkpay",
                 "req" => Jason.encode!(payload),
                 "body" => body
               }),
             {:ok, resp} <- Jason.decode(body) do
          {:ok, resp}
        end
      end

      @spec sign(unk_cli(), %{String.t() => term()}) :: binary()
      defp sign(cli, attrs) do
        str_pre =
          attrs
          |> Map.reject(fn {_, v} -> v in ["", nil] end)
          |> sort_and_concat(true)

        string2sign = str_pre <> "&key=" <> cli.appkey

        string2sign
        |> Sonnam.Utils.CryptoUtil.md5()
        |> Base.encode16()
      end

      @spec verify_response(%{String.t() => term()}) :: boolean
      def verify_response(params) do
        cli = get_cli()
        {signature, attrs} = Map.pop(params, "sign")
        sign(cli, attrs) == signature
      end
    end
  end
end
