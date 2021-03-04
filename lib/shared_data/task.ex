defmodule Sonnam.TaskData do
  @moduledoc """
  event枚举
  """

  defmacro ping, do: 1

  # 解锁任务
  defmacro unlock_plans, do: 10001
end
