# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input -> res == :ok end,
#   true
# )

# Injector.out("./tests/example_module.ex", :check_string, "./", true)

generic_test = fn res, _input -> res == :ok end
file = "./tests/custom_benchmarks.ex"

test_1 = {file, :flat_branch, generic_test}
test_2 = {file, :constructive_branch, generic_test}
test_3 = {file, :constructive_branch_mult, generic_test}
test_4 = {file, :unrelated_branch, generic_test}

cases = [test_2]

full_capability = {true, true, true}
no_trim = {true, true, false}
no_mask = {true, false, false}
no_schedule = {false, false, false}

t = 1000
iters = 100

timeout = 60 * t
f = "benchmark60.csv"
Bench.run(cases, full_capability, iters, timeout, f)
Bench.run(cases, no_trim, iters, timeout, f)
Bench.run(cases, no_mask, iters, timeout, f)
Bench.run(cases, no_schedule, iters, timeout, f)

timeout = 180 * t
f = "benchmark180.csv"
Bench.run(cases, full_capability, iters, timeout, f)
Bench.run(cases, no_trim, iters, timeout, f)
Bench.run(cases, no_mask, iters, timeout, f)
Bench.run(cases, no_schedule, iters, timeout, f)

timeout = 300 * t
f = "benchmark300.csv"
Bench.run(cases, full_capability, iters, timeout, f)
Bench.run(cases, no_trim, iters, timeout, f)
Bench.run(cases, no_mask, iters, timeout, f)
Bench.run(cases, no_schedule, iters, timeout, f)

timeout = 900 * t
f = "benchmark900.csv"
Bench.run(cases, full_capability, iters, timeout, f)
Bench.run(cases, no_trim, iters, timeout, f)
Bench.run(cases, no_mask, iters, timeout, f)
Bench.run(cases, no_schedule, iters, timeout, f)

timeout = 1800 * t
f = "benchmark1800.csv"
Bench.run(cases, full_capability, iters, timeout, f)
Bench.run(cases, no_trim, iters, timeout, f)
Bench.run(cases, no_mask, iters, timeout, f)
Bench.run(cases, no_schedule, iters, timeout, f)
