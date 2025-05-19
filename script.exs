# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input ->
#     res == :good
#     # false
#   end,
#   false
# )
# |> IO.inspect()

# mod = PropEl.benchmark_prep("./tests/example_module.ex", :check_string)
# property = fn _res, _input -> false end
# PropEl.benchmark_runner(mod, property) |> IO.inspect()

# test_two = {"./tests/example_module.ex", :check_other_string, :fuzz_string, fn res, _input ->
#   res == :good
# end}

# test_three = {"./tests/example_module_two.ex", :check_string, :fuzz_string, fn res, _input ->
#   res == :good
# end}

test_one = {"./tests/example_module.ex", :check_string, fn res, _input -> res == :good end}
Bench.test_suite([test_one], 10)
# Bench.test_suite([test_one, test_two, test_three])

# # Injector._instrument("./example_module.ex", :test5, 1, "./", true)
