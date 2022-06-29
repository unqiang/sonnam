defmodule Sonnam.Utils.Trace  do

  def recon_memory(n) do
    :recon.proc_count(:memory, n)
  end

  def recon_msq(n) do
    :recon.proc_count(:message_queue_len, n)
  end

  def get_state(pid, timeout \\ 5000) do
      ensure_pid(pid)
      :sys.get_state(pid, timeout)
  end

  def ensure_pid(pid) when is_list(pid) do
    :erlang.list_to_pid(pid)
  end
  def ensure_pid(pid) when is_pid(pid) do
    pid
  end
  def ensure_pid(pid) when is_binary(pid) do
    :erlang.binary_to_list(pid)
    |>ensure_pid()
  end


end
