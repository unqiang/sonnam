defmodule Sonnam.AliyunOss.Client do
  @moduledoc false

  use Strukt

  defstruct do
    field :endpoint, :string
    field :access_key_id, :string
    field :access_key_secret, :string
    field :bucket, :string
  end
end