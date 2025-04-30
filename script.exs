Code.require_file("./lib/fuzzer.ex")
Code.require_file("./lib/inject.ex")

Injector.handle("./example_module.ex", "./", true)
