defmodule BenchmarkTests do
  def flat(str) do
    if String.contains?(str, "crash") do
      raise "Crash"
    end

    :ok
  end

  def nested(str) do
    if String.starts_with?(str, "abc") do
      if String.ends_with?(str, "def") do
        raise "Crash"
      end
    end

    :ok
  end

  def mult(str) do
    if String.starts_with?(str, "PRE") do
      if String.starts_with?(str, "PRE1") do
        raise "Crash"
      end

      if String.starts_with?(str, "PRE2") do
        :ok
      end

      if String.starts_with?(str, "PRE3") do
        :ok
      end

      if String.starts_with?(str, "PRE4") do
        :ok
      end

      if String.starts_with?(str, "PRE5") do
        :ok
      end
    end

    :ok
  end
end
