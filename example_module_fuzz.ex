defmodule NumberChecker do
  @moduledoc "A module that checks if a number is positive, negative, or zero.\n"
  @doc "Checks the given number and returns a descriptive string.\n"
  def test() do
    branch_ids = []

    try do
      :hello
    catch
      e -> {e, branch_ids}
    end

    branch_ids
  end

  def check_number(num) do
    branch_ids = []

    try do
      if num > 0 do
        "#{num} is positive"
      else
        if num < 0 do
          "#{num} is negative"
        else
          "The number is zero"
        end
      end
    catch
      e -> {e, branch_ids}
    end

    branch_ids
  end
end