# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input -> res == :ok end,
#   true
# )

# Injector.out("./tests/example_module.ex", :check_string, "./", true)

file = "./tests/custom_benchmarks.ex"
generic_test = fn res, _input -> res == :ok end

nested = {file, :nested, generic_test}
# mult = {file, :mult, generic_test}
# test_3 = {file, :flat, generic_test}

# all_cases = [nested, mult]

# full_r = {true, true, true, true}
# mask_r = {true, true, false, true}
# full = {true, true, true, false}
mask = {true, true, false, false}
# scheduler = {true, false, false, false}
# random = {false, false, false, false}

all_configs = [mask]

t = 1000
iters = 100

timeout = 60 * 5 * t
f = "spare_nested.csv"

all_configs
|> Enum.map(fn config ->
  Bench.run([nested], config, iters, timeout, f)
end)
