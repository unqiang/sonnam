defmodule MiniappTest do
  use ExUnit.Case

  import Sonnam.Wechat.Miniapp

  @cfg [
    app_id: "wxefd6b215fca0cacd",
    app_secret: "5de648e8804432e6db204c318c402bb7"
  ]

  setup_all do
    @cfg
    |> get_access_token()
  end

  test "get wechat unlimited", ctx do
    ctx[:access_token]
    |> get_unlimited_wxacode(scene: "a=b" |> URI.encode())
    |> then(fn {:ok, image} -> image end)
    |> then(fn x -> File.write("/tmp/wx.png", x) end)
  end

  test "get_urllink", ctx do
    ctx[:access_token]
    |> get_urllink(query: "a=1", is_expire: true, expire_type: 1, expire_interval: 2)
    |> then(fn {:ok, resp} -> IO.inspect(resp) end)
  end
end
