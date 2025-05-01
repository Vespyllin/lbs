defmodule NumberChecker do
  @moduledoc "A module that checks if a number is positive, negative, or zero.\n"
  @doc "Checks the given number and returns a descriptive string.\n"
  def check_number3(num) do
    (
      state_pid =
        spawn(fn ->
          state = []

          receive_loop = fn receive_loop, state ->
            receive do
              id -> receive_loop.(receive_loop, [id | state])
              {:request, requestor_pid} -> send(requestor_pid, {:response, state})
              _ -> receive_loop.(receive_loop, state)
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

  def check_number2(num) do
    (
      state_pid =
        spawn(fn ->
          state = []

          receive_loop = fn receive_loop, state ->
            receive do
              id -> receive_loop.(receive_loop, [id | state])
              {:request, requestor_pid} -> send(requestor_pid, {:response, state})
              _ -> receive_loop.(receive_loop, state)
            end
          end

          receive_loop.(receive_loop, [])
        end)

      res =
        try do
          if num > 0 do
            send(state_pid, "S-1T")
            :positive
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

  def check_number(num) do
    (
      state_pid =
        spawn(fn ->
          state = []

          receive_loop = fn receive_loop, state ->
            receive do
              id -> receive_loop.(receive_loop, [id | state])
              {:request, requestor_pid} -> send(requestor_pid, {:response, state})
              _ -> receive_loop.(receive_loop, state)
            end
          end

          receive_loop.(receive_loop, [])
        end)

      res =
        try do
          :test

          if num > 0 do
            send(state_pid, "S-1T")
            :positive
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