PropEl.propel(
  "./tests/custom_benchmarks.ex",
  :constructive_branch,
  fn res, _input -> res == :ok end,
  true
)

# Injector.out("./tests/example_module.ex", :check_string, "./", true)

# test_1 = {"./tests/custom_benchmarks.ex", :constructive_branch, fn res, _input -> res == :ok end}

# t = 1000
# iters = 12

# timeout1 = 60 * t
# Bench.run(test_1, {true, true, true}, iters, timeout1)
# Bench.run(test_1, {true, true, false}, iters, timeout1)
# Bench.run(test_2, {true, true, true}, iters, timeout1)
# Bench.run(test_2, {true, true, false}, iters, timeout1)

# Bench.run(test_1, {true, false, false}, iters, timeout1)
# Bench.run(test_1, {false, false, false}, iters, timeout1)

# # timeout2 = 180 * t
# # Bench.run(test_1, {true, true, true}, iters, timeout2)
# # Bench.run(test_1, {true, true, false}, iters, timeout2)
# # Bench.run(test_1, {true, false, false}, iters, timeout2)
# # Bench.run(test_1, {false, false, false}, iters, timeout2)

# # timeout3 = 6000 * t
# # Bench.run(test_1, {true, true, true}, iters, timeout3)
# # Bench.run(test_1, {true, true, false}, iters, timeout3)
# # Bench.run(test_1, {true, false, false}, iters, timeout3)
# # Bench.run(test_1, {false, false, false}, iters, timeout3)
