# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input -> res == :ok end,
#   true
# )

# mod = PropEl.benchmark_prep("./tests/example_module.ex", :check_string)

# PropEl.benchmark_runner(mod, fn res, _input -> res == :ok end, false, false, false, false)

Injector.out("./tests/example_module.ex", :check_string, "./", true)

# file = "./tests/custom_benchmarks.ex"
# generic_test = fn res, _input -> res == :ok end

# # nested = {file, :nested, generic_test}
# mult = {file, :mult, generic_test}

# # all_cases = [nested, mult]

# full = {true, true, true, false}
# mask = {true, true, false, false}
# # scheduler = {true, false, false, false}
# # random = {false, false, false, false}

# all_configs = [full, mask]

# t = 1000
# iters = 96

# timeout = 60 * 5 * t
# f = "coverage_high_2.csv"

# all_configs
# |> Enum.map(fn config ->
#   Bench.run([mult], config, iters, timeout, f)
# end)
