defmodule Sonnam.Utils.Tool  do

  def recon_memory(n \\10) do
    :recon.proc_count(:memory, n)
  end

  def recon_msq(n \\10) do
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

  # def gen_code(module)  do
  #   p = :code.which(module)
  #   {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(p,  [:abstract_code])
  #   IO.write(:erl_prettypr.format(:erl_syntax.form_list(ac)))
  # end

  #To get compile module_info information
  def compile_info(module) do
      try do
        module.module_info()
      rescue
        _undefined ->
            IO.puts "undefined, please check module name for beam file"
      end
  end
end
