PropEl.handle("./example_module.ex", :check_string, 1, :fuzz_string, fn res, _input ->
  res == :good
end)

# Injector._instrument("./example_module.ex", :check_string, 1, "./", true)
# Code.require_file("./example_module_fuzz.ex")
