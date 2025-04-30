defmodule NumberChecker do
  @moduledoc """
  A module that checks if a number is positive, negative, or zero.
  """

  @doc """
  Checks the given number and returns a descriptive string.
  """
  def test() do
    :hello
  end
  
  def check_number(num) do
    if num > 0 do
      "#{num} is positive"
    else 
      if num < 0 do
          "#{num} is negative"
      else
          "The number is zero"
      end
    end  
  end
end