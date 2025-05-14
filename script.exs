Code.require_file("./lib/Injector.ex")
Code.require_file("./lib/Fuzzer.ex")
Code.require_file("./lib/Blame.ex")
Code.require_file("./lib/PropEl.ex")

PropEl.handle("./example_module.ex", :check_number, 1, [:fuzz_number], fn x ->
  x in [:positive, :negative, :zero]
end)

# Injector._instrument("./example_module.ex", :check_number, 1, "./", true)
# Code.require_file("./example_module_fuzz.ex")

# read_res = File.read!("./example_module.ex")
# ast = Code.string_to_quoted!(read_res)
# Blame.blame(ast, ["S-1F", "S-2T"], :check_number, 1)
