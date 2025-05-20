defmodule BenchmarkTests do
  def random_crash(str) do
    if String.contains?(str, "bad") do
      raise "Crash"
    end

    :ok
  end

  def constructive_branch_mult(string) do
    if String.contains?(string, "aa") do
      if String.contains?(string, "bb") do
        if String.contains?(string, "aaaa") do
          raise "Crash"
        end

        if String.contains?(string, "dddd") do
          :ok
        end

        if String.contains?(string, "eeee") do
          :ok
        end

        if String.contains?(string, "ffff") do
          :ok
        end
      end
    end

    :ok
  end

  def constructive_branch(data) do
    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        # aa before bb
        if String.split(data, "bb") |> hd() |> String.contains?("aa") do
          raise "Crash"
        end
      end
    end

    :ok
  end

  def unrelated_branch(data) do
    letters = String.graphemes(data)

    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        if Enum.count(letters, fn letter -> letter == "c" end) / letters >= 0.5 do
          raise "Crash"
        end
      end
    end

    :ok
  end
end
