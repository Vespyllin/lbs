# Instrument the example module and output the results to a file
PropEl.out("./tests/example_module.ex", :check_string, "./")

IO.puts("")

# Fuzz the example module
PropEl.propel(
  "./tests/example_module.ex",
  :check_string,
  fn res, _input -> res == :ok end
)
