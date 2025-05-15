PropEl.handle("./example_module.ex", :test2, 1, :fuzz_string, fn res, _input ->
  res == :a
end)

# Injector._instrument("./example_module.ex", :test, 1, "./", true)
