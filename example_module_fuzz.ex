defmodule NumberChecker do
  (
    defp state_server(state) do
      receive do
        {:request, requestor_pid} -> send(requestor_pid, {:response, state})
        id -> state_server([id | state])
      end
    end

    def hook(fuzzed_params) when is_list(fuzzed_params) do
      state_pid = spawn(fn -> state_server(["root"]) end)
      apply(__MODULE__, :check_number, fuzzed_params ++ [state_pid])
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

  def check_number(-2, state_pid) do
    (
      res =
        try do
          :positive
        rescue
          e -> e
        end

      send(state_pid, {:request, self()})

      receive do
        {:response, list} -> {res, list}
      end
    )
  end

  def check_number(num, state_pid) do
    (
      res =
        try do
          if num > 0 do
            send(state_pid, "S-1T")
            :positive
          else
            send(state_pid, "S-1F")

            if num < 0 do
              send(state_pid, "S-1F-3T")
              :negative
            else
              send(state_pid, "S-1F-3F")
              raise "ERR"
              :zero
            end
          end
        rescue
          e -> e
        end

      send(state_pid, {:request, self()})

      receive do
        {:response, list} -> {res, list}
      end
    )
  end
end