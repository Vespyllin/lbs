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
mult = {file, :mult, generic_test}

# full = {true, true, true, false}
# mask = {true, true, false, false}
scheduler = {true, false, false, false}
random = {false, false, false, false}

all_cases = [nested, mult]
all_configs = [scheduler, random]

iters = 4
timeout = 60 * 60 * 1000
f = "sched_rand_4_60.csv"

all_configs
|> Enum.map(fn config ->
  Bench.run(all_cases, config, iters, timeout, f)
end)
