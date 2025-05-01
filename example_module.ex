defmodule NumberChecker do
  @moduledoc """
  A module that checks if a number is positive, negative, or zero.
  """

  @doc """
  Checks the given number and returns a descriptive string.
  """
  def check_number3(num) do
    if num > 0 do
      :positive
    else
      if num < 0 do
        :negative
      else
        raise "ERR"
        :zero
      end
    end
  end
end
