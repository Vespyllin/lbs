Code.require_file("./lib/inject.ex")
Code.require_file("./lib/fuzzer.ex")
Code.require_file("./lib/PropEl.ex")

PropEl.handle("./example_module.ex", :check_number, 1, [:number], fn x ->
    x in [:positive, :negative, :zero]
end)

# Injector._handle("./example_module.ex", :check_number, 1, "./", true)
# Code.require_file("./example_module_fuzz.ex")
