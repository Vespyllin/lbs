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

    if "Z" in letters and String.length(str) > 1024 do
      :good
    end

    if "a" in letters and "c" in letters do
      if "d" in letters and "e" in letters do
        raise "no air conditioning allowed"
      end
    end

    :good
  end
end
