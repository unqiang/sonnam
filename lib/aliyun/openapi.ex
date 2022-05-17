defmodule Sonnam.Aliyun.Openapi do
  @moduledoc false

  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      @otp_app unquote(otp_app)
      @http_method %{
        post: "POST",
        get: "GET"
      }

      defp config do
        @otp_app
        |> Application.get_env(__MODULE__)
      end

      @spec rpc_call(
              action :: String.t(),
              endpoint :: String.t(),
              version :: String.t(),
              method :: :post | :get,
              params :: %{String.t() => any()},
              keyword()
            ) :: {:ok, term()}
      def rpc_call(action, endpoint, version, method, params, opts \\ [recv_timeout: 2000]) do
        cfg = config()

        pub_params = %{
          "Action" => action,
          "Version" => version,
          "Format" => "json",
          "AccessKeyId" => cfg[:access_key_id],
          "SignatureNonce" => Sonnam.Utils.CryptoUtil.random_string(12),
          "Timestamp" => timestamp(),
          "SignatureMethod" => "HMAC-SHA1",
          "SignatureVersion" => "1.0"
        }

        signature =
          Sonnam.Aliyun.Utils.sign(
            @http_method[method],
            Map.merge(pub_params, params),
            cfg[:access_key_secret]
          )

        req =
          case method do
            :post ->
              %HTTPoison.Request{
                method: :post,
                url: endpoint,
                headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
                body: URI.encode_query(params, :rfc3986),
                params: Map.put(pub_params, "Signature", signature),
                options: opts
              }

            :get ->
              attrs =
                Map.merge(pub_params, params)
                |> Map.put("Signature", signature)

              %HTTPoison.Request{
                method: :post,
                url: endpoint,
                headers: [],
                body: "",
                params: attrs,
                options: opts
              }
          end

        {:ok, %HTTPoison.Response{body: body, status_code: 200}} = HTTPoison.request(req)

        Jason.decode(body)
      end

      defp timestamp() do
        {:ok, dt} = Sonnam.Utils.TimeUtil.now()

        dt
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()
      end
    end
  end
end
