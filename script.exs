Code.require_file("./lib/inject.ex")
# Code.require_file("./example_module_fuzz.ex")

Injector.handle("./example_module.ex", "./", true)
# IO.inspect(NumberChecker.check_number(0))
