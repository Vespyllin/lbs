Code.require_file("./lib/inject.ex")
Code.require_file("./lib/fuzzer.ex")
Code.require_file("./lib/PropEl.ex")
# Code.require_file("./example_module_fuzz.ex")

# Injector._handle("./example_module.ex", :check_number, 1, "./", true)
PropEl.handle("./example_module.ex", :check_number, 1)
# Injector.handle("./example_module.ex", :check_number, 1)
# IO.inspect(NumberChecker.hook([-2]))
# IO.inspect(NumberChecker.check_number3(-1))
# IO.inspect(NumberChecker.check_number3(1))

# PropEl.hello()
# x =
#   quote do
#     defp test(a, b, c) do
#       IO.puts(a)
#       IO.puts(b)
#       IO.puts(c)
#     end
#   end

# IO.inspect(x)
