defmodule NumberChecker do
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

  def check_number(num) do
    :test

    if num > 0 do
      :positive
    else
      if num < 0 do
        :test

        if num < -1000 and num > -1050 do
          raise "YA FOUND ME"
        end

        :negative
      else
        :zero
      end
    end
  end

  def fuzz_target(str, state_pid) do
    try do
      if "ab" in String.graphemes(str) do
        send(state_pid, "S-1T")
        raise "A"
      end

      :good
    rescue
      e -> e
    end
  end
end