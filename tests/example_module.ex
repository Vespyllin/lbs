defmodule NumberChecker do
  # def check_number(num) do
  #   :test

  #   if num > 0 do
  #     :positive
  #   else
  #     if num < 0 do
  #       :test

  #       if num < -1000 and num > -1050 do
  #         raise "YA FOUND ME"
  #       end

  #       :negative
  #     else
  #       :zero
  #     end
  #   end
  # end

  # def check_other_string(str) do
  #   if String.ends_with?(str, "c"), do: raise("Bad string"), else: :ok
  # end

  # def test2(param) do
  #   case param do
  #     n when is_number(n) ->
  #       :num
  #       :num2

  #     _s ->
  #       :str
  #   end
  # end

  # def test3(param) do
  #   cond do
  #     String.length(param) < 18 -> :a
  #     String.length(param) > 20 -> :a
  #     true -> :b
  #   end
  # end

  # def test4(param) do
  #   unless param do
  #     :a
  #   else
  #     :b
  #   end
  # end

  # def test5(param) do
  #   :testline

  #   with {:no, _y} <- param do
  #     raise "BAD"
  #   else
  #     _x -> "GOOD"
  #     {:isok, _reason} -> :wow
  #   end
  # end

  # def test(param) do
  #   if param != nil do
  #     :a
  #   else
  #     :b
  #   end

  #   unless false do
  #     :c
  #   else
  #     :d
  #   end
  # end
  def check_string(str) do
    x = fn y ->
      if y do
        :good
      end

      for n <- 1..100 do
        if y do
          :good
        end
      end
    end

    # letters = String.graphemes(str)

    # if "b" in letters do
    #   if Enum.count(letters, fn letter -> letter == "a" end) > 3 do
    #     raise "BAD"
    #   end
    # end

    # :ok
  end

  # def check_att(string) do
  #   if String.starts_with?(string, "ATT") do
  #     case string do
  #       "ATT3" -> raise "BAD"
  #       _ -> :ok
  #     end
  #   else
  #     :ok
  #   end
  # end
end
