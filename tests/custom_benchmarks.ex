defmodule BenchmarkTests do
  def constructive_branch(data) do
    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        if String.split(data, "bb") |> hd() |> String.ends_with?("aa") do
          raise "Crash: fragile sequence hit"
        end
      end
    end

    :ok
  end

  def constructive_branch_stall(data) do
    _res = Enum.reduce(1..100_000, fn x, acc -> acc + :rand.uniform(x) end)

    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        if String.split(data, "bb") |> hd() |> String.ends_with?("aa") do
          raise "Crash: fragile sequence hit"
        end
      end
    end

    :ok
  end

  def unrelated_branch(data) do
    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        if String.split(data, "bb") |> hd() |> String.ends_with?("aa") do
          raise "Crash: fragile sequence hit"
        end
      end
    end

    :ok
  end

  def unrelated_branch_stall(data) do
    _res = Enum.reduce(1..100_000, fn x, acc -> acc + :rand.uniform(x) end)

    if String.contains?(data, "aa") do
      if String.contains?(data, "bb") do
        if String.split(data, "bb") |> hd() |> String.ends_with?("aa") do
          raise "Crash: fragile sequence hit"
        end
      end
    end

    :ok
  end
end
