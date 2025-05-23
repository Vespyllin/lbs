defmodule Tester do
  def check_string(str) do
    # IO.puts("Checking string...")

    if(String.contains?(str, "b")) do
      if String.contains?(str, "bad") do
        raise "ERR"
      end
    end

    :ok
  end
end
