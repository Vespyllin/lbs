#PropEl.propel("./tests/example_module.ex", :check_number, 1, :fuzz_number, fn res, _input ->
#  res == :good
#end)

test_one = {"./tests/example_module.ex", :check_string, :fuzz_string, fn res, _input ->
  res == :good
end}

test_two = {"./tests/example_module.ex", :check_other_string, :fuzz_string, fn res, _input ->
  res == :good
end}

test_three = {"./tests/example_module_two.ex", :check_string, :fuzz_string, fn res, _input ->
  res == :good
end}

Bench.test_suite([test_one, test_two, test_three])

# Injector._instrument("./example_module.ex", :test5, 1, "./", true)
