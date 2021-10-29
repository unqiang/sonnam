defmodule MiniappTest do
  use ExUnit.Case

  import Sonnam.Wechat.Miniapp

  @cfg [
    app_id: "wxefd6b215fca0cacd",
    app_secret: "5de648e8804432e6db204c318c402bb7"
  ]

  test "get wechat unlimited" do
    @cfg
    |> get_access_token()
    |> then(fn {:ok, %{access_token: token}} -> token end)
    |> get_unlimited_wxacode(scene: "a=b" |> URI.encode())
    |> then(fn {:ok, image} -> image end)
    |> then(fn x -> File.write("/tmp/wx.png", x) end)
  end
end
