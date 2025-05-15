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

  def check_string(str) do
    letters = String.graphemes(str)

    if "Z" in letters and String.length(str) > 1024 do
      :good
    end

    if "a" in letters and "c" in letters do
      if "d" in letters and "e" in letters do
        raise "no air conditioning allowed"
      end
    end

    check_string(str)
    :good
  end

  def test2(param) do
    case param do
      n when is_number(n) ->
        :num
        :num2

      _s ->
        :str
    end
  end

  def test3(param) do
    cond do
      String.length(param) < 18 -> :a
      String.length(param) > 20 -> :a
      true -> :b
    end
  end

  def test4(param) do
    unless param do
      :a
    else
      :b
    end
  end

  def fuzz_target(param, state_pid) do
    try do
      :testline

      with {:no, _y} <- param do
        send(state_pid, "S-2WT")
        raise "BAD"
      else
        {_x} ->
          send(state_pid, "S-2WF1")
          "GOOD"

        {:isok, _reason} ->
          send(state_pid, "S-2WF2")
          :wow
      end
    rescue
      e -> e
    end
  end

  def test5(param) do
    :testline

    with {:no, _y} <- param do
      raise "BAD"
    else
      {_x} -> "GOOD"
      {:isok, _reason} -> :wow
    end
  end

  def test param do
    if param != nil do
      :a
    else
      :b
    end

    unless false do
      :c
    else
      :d
    end
  end
end