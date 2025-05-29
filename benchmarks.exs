file = "./tests/custom_benchmarks.ex"
generic_test = fn res, _input -> res == :ok end

nested = {file, :nested, generic_test}
mult = {file, :mult, generic_test}

trim = {true, true, true, false}
mask = {true, true, false, false}
schd = {true, false, false, false}
rand = {false, false, false, false}

t = 60 * 1000

conc = System.schedulers_online()
iters = 100
timeout = 15 * t
f = "benchmarks_#{iters}_#{floor(timeout / t)}.csv"

[trim, mask, schd, rand]
|> Enum.each(fn config ->
  Bench.run([nested, mult], config, iters, timeout, conc, f)
end)
