import Fuzzer
import Injector

defmodule Injector do
  def hello() do
    Fuzzer.hello()
    Injector.hello()
  end
end
