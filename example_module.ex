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
    if "Z" in String.graphemes(str) do
      :good
    end

    if "a" in String.graphemes(str) do
      if "b" in String.graphemes(str) do
        :good
      end

      if "c" in String.graphemes(str) do
        raise "no air conditioning allowed"
      end
    end

    :good
  end
end
