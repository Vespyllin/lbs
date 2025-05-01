defmodule NumberChecker do
  @moduledoc "A module that checks if a number is positive, negative, or zero.\n"
  @doc "Checks the given number and returns a descriptive string.\n"
  def check_number3(num) do
    (
      state_pid =
        spawn(fn ->
          receive_loop = fn receive_loop, state ->
            receive do
              {:request, requestor_pid} -> send(requestor_pid, {:response, state})
              id -> receive_loop.(receive_loop, [id | state])
            end
          end

          receive_loop.(receive_loop, [])
        end)

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
              :zero
            end
          end
        catch
          e -> e
        end

      send(state_pid, {:request, self()})

      receive do
        {:response, list} -> {res, list}
      end
    )
  end
end