defmodule BenchmarkTests do
  def flat_branch(str) do
    if String.contains?(str, "badinput") do
      raise "Crash"
    end

    :ok
  end

  def constructive_branch(str) do
    if String.contains?(str, "abc") do
      if String.contains?(str, "def") do
        if String.contains?(str, "abc11") or String.contains?(str, "defg22") do
          raise "Crash"
        end
      end
    end

    :ok
  end

  def constructive_branch_mult(str) do
    if String.contains?(str, "aaa") do
      if String.contains?(str, "bbb") do
        if String.contains?(str, "aaa11") do
          raise "Crash"
        end

        if String.contains?(str, "bbb22") do
          :ok
        end

        if String.contains?(str, "ddddd") do
          :ok
        end

        if String.contains?(str, "eeeee") do
          :ok
        end

        if String.contains?(str, "fffff") do
          :ok
        end
      end
    end

    :ok
  end

  def unrelated_branch(str) do
    if String.contains?(str, "abc") do
      if String.contains?(str, "def") do
        if String.contains?(str, "vwxyz") or String.contains?(str, "lmnop") do
          raise "Crash"
        end
      end
    end

    :ok
  end
end
