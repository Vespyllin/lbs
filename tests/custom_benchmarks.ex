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
    if String.starts_with?(str, "PR_") do
      if String.starts_with?(str, "PR_bad") do
        raise "Crash"
      end

      if String.starts_with?(str, "PR_XYZ") do
        :ok
      end

      if String.starts_with?(str, "PR_xyz") do
        :ok
      end

      if String.starts_with?(str, "PR_yzx") do
        :ok
      end

      if String.starts_with?(str, "PR_zxy") do
        :ok
      end
    end

    :ok
  end
end
