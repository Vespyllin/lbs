defmodule NumberChecker do
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

    if "b" in letters do
      if "a" in letters do
        if String.contains?(str, "bad") do
          raise "BAD"
        end
      end
    end

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

  def test5(param) do
    :testline

    with {:no, _y} <- param do
      raise "BAD"
    else
      _x -> "GOOD"
      {:isok, _reason} -> :wow
    end
  end

  def test(param) do
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
