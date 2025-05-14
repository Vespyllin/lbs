defmodule Whatever do
  def fib(n) do
    :test_1

    if n <= 1 do
      n
    else
      if(n > 200) do
        n + 100
      end
    end

    if(n == 0) do
      :test
    end
  end

  def a() do
    :test
  end
end
