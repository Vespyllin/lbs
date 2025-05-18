defmodule Tester do


  def check_string(str) do
    if String.starts_with?(str, "c"), do: (raise "bad string"), else: :good
  end
end
