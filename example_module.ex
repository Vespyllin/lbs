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
    :test

    if num > 0 do
      :positive
    else
      if num < 0 do
        if num < -1000 and num > -1050 do
          raise "YA FOUND ME"
        end

        :negative
      else
        :zero
      end
    end
  end
end
