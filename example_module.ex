defmodule NumberChecker do
  @moduledoc """
  A module that checks if a number is positive, negative, or zero.
  """

  @doc """
  Checks the given number and returns a descriptive string.
  """
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

  def check_number(num) do
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
