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

  @moduledoc "A module that checks if a number is positive, negative, or zero.\n"
  @doc "Checks the given number and returns a descriptive string.\n"
  def not_check_number() do
    :positive
  end

  def check_number() do
    :positive
  end

  def check_number(-2, -3) do
    :positive
    :negative
  end

  def fuzz_target(num, state_pid) do
    try do
      if num > 0 do
        send(state_pid, "S-1T")
        :positive
      else
        send(state_pid, "S-1F")

        if num < 0 do
          send(state_pid, "S-1F-3T")

          if num < -1000 and num > -1050 do
            send(state_pid, "S-1F-3T-4T")
            raise "ERR"
          end

          :negative
        else
          send(state_pid, "S-1F-3F")
          :zero
        end
      end
    rescue
      e -> e
    end
  end
end