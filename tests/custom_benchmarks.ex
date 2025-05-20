defmodule BenchmarkTests do
  def random_crash(str) do
    if String.contains?(str, "bad") do
      raise "Crash"
    end

    :ok
  end

  def constructive_branch_mult(str) do
    if String.contains?(str, "aa") do
      if String.contains?(str, "bb") do
        if String.contains?(str, "aaaa") do
          raise "Crash"
        end

        if String.contains?(str, "dddd") do
          :ok
        end

        if String.contains?(str, "eeee") do
          :ok
        end

        if String.contains?(str, "ffff") do
          :ok
        end
      end
    end

    :ok
  end

  def constructive_branch(str) do
    if String.contains?(str, "ab") do
      if String.contains?(str, "cd") do
        # aa before bb
        if String.contains?(str, "cdab") do
          raise "Crash"
        end
      end
    end

    :ok
  end

  def unrelated_branch(str) do
    if String.contains?(str, "ab") do
      if String.contains?(str, "cd") do
        if String.contains?(str, "efgh") do
          raise "Crash"
        end
      end
    end

    :ok
  end
end
