defmodule Whatever do
  (
    defp state_server(state) do
      receive do
        {:request, requestor_pid} -> send(requestor_pid, {:response, state})
        id -> state_server(state ++ [id])
      end
    end

    def hook(fuzzed_params) when is_list(fuzzed_params) do
      state_pid = spawn(fn -> state_server([]) end)
      res = apply(__MODULE__, :fuzz_target, fuzzed_params ++ [state_pid])
      send(state_pid, {:request, self()})

      receive do
        {:response, list} -> {res, list}
      end
    end
  )

  def fuzz_target(n, state_pid) do
    try do
      :test_1

      if n <= 1 do
        send(state_pid, "S-1T")
        n
      else
        send(state_pid, "S-1F")

        if n > 200 do
          send(state_pid, "S-1F-3T")
          n + 100
        end
      end

      if n == 0 do
        send(state_pid, "S-2T")
        :test
      end
    rescue
      e -> e
    end
  end

  def a() do
    :test
  end
end