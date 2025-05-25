# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input -> res == :ok end,
#   true
# )

# Injector.out("./tests/example_module.ex", :check_string, "./", true)

file = "./tests/custom_benchmarks.ex"
generic_test = fn res, _input -> res == :ok end

test_1 = {file, :nested, generic_test}
test_2 = {file, :mult, generic_test}
test_3 = {file, :flat, generic_test}

all_cases = [test_1, test_2, test_3]
no_flat = [test_1, test_2]

full_opt_rotate = {true, true, true, true}
no_trim_rotate = {true, true, false, true}
full_opt = {true, true, true, false}
no_trim = {true, true, false, false}
no_mask = {true, false, false, false}
none = {false, false, false, false}

t = 1000
iters = 100

timeout = 60 * 5 * t
f = "benchmark_5_100_with_rotate.csv"
Bench.run(no_flat, full_opt_rotate, iters, timeout, f)
Bench.run(no_flat, no_trim_rotate, iters, timeout, f)
Bench.run(all_cases, full_opt, iters, timeout, f)
Bench.run(all_cases, no_trim, iters, timeout, f)
Bench.run(all_cases, no_mask, iters, timeout, f)
Bench.run(all_cases, none, iters, timeout, f)
