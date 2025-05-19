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

Injector.out("./tests/example_module.ex", :check_att, 1, "./", true)

# test_one =
#   {"./tests/custom_benchmarks.ex", :constructive_branch, fn res, _input -> res == :ok end}

# _test_two =
#   {"./tests/custom_benchmarks.ex", :constructive_branch_stall, fn res, _input -> res == :ok end}

# cases = [test_one]

# t = 1000

# iters = 12

# timeout1 = 30 * t
# Bench.run(cases, {true, true}, iters, timeout1)
# Bench.run(cases, {true, false}, iters, timeout1)
# Bench.run(cases, {false, false}, iters, timeout1)

# # timeout2 = 180 * t
# # Bench.run(cases, {true, true}, iters, timeout2)
# # Bench.run(cases, {true, false}, iters, timeout2)
# # Bench.run(cases, {false, false}, iters, timeout2)

# # timeout3 = 6000 * t
# # Bench.run(cases, {true, true}, iters, timeout3)
# # Bench.run(cases, {true, false}, iters, timeout3)
# # Bench.run(cases, {false, false}, iters, timeout3)
