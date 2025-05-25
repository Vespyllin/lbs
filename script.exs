# PropEl.propel(
#   "./tests/example_module.ex",
#   :check_string,
#   fn res, _input -> res == :ok end,
#   true
# )

# Injector.out("./tests/example_module.ex", :check_string, "./", true)

file = "./tests/custom_benchmarks.ex"
generic_test = fn res, _input -> res == :ok end

test_1 = {file, :nested,    generic_test}
test_2 = {file, :mult,      generic_test}
test_3 = {file, :flat,      generic_test}

cases = [test_1, test_2, test_3]

# full_opt    =   {true, true, true}
no_trim     =   {true, true, false}
no_mask     =   {true, false, false}
none        =   {false, false, false}

t = 1000
iters = 100

timeout = 60 * 5 * t
f = "benchmark300.csv"
# Bench.run(cases, full_opt,  iters, timeout, f)
# Bench.run(cases, no_trim,   iters, timeout, f)
# Bench.run(cases, no_mask,   iters, timeout, f)
Bench.run(cases, none,      iters, timeout, f)