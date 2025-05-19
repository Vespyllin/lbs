require PropEl

defmodule Bench do
  # 5 Minutes
  @timeout 5000

  defp run_with_timeout(fn_ref, timeout) do
    self = self()
    fuzzer_pid = spawn(fn -> send(self, fn_ref.()) end)

    receive do
      res -> res
    after
      timeout ->
        Process.exit(fuzzer_pid, :kill)
        {:timeout}
    end
  end

  def time({loc, fn_name, property}, iterations \\ 5) do
    # Instrument and compile target module once
    IO.puts("Injecting fuzzer code into #{loc}.")
    mod = PropEl.benchmark_prep(loc, fn_name)

    IO.puts("Running #{iterations} fuzzing loops with a #{floor(@timeout / 1000)}s timeout.")

    res =
      1..iterations
      |> Task.async_stream(
        fn idx ->
          IO.puts("Spawning loop #{idx}.")

          :timer.tc(fn ->
            run_with_timeout(fn -> PropEl.benchmark_runner(mod, property) end, @timeout)
          end)
        end,
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      )
      |> Enum.with_index()
      |> Enum.map(fn {{:ok, result}, idx} ->
        IO.puts("Loops finished: #{idx + 1}")
        result
      end)

    IO.puts("Printing results.")

    {Path.basename(loc, ".ex") <> "::" <> to_string(fn_name), res}
  end

  def test_suite(suite, iterations \\ 5) do
    suite
    |> Enum.map(fn test_case -> time(test_case, iterations) end)
    |> summary()
    |> print_summaries()
  end

  def summary(suite_res) do
    suite_res
    |> Enum.map(fn {name, results} ->
      {bugs_found, total_time, min_time, max_time, total_iter, min_iter, max_iter} =
        Enum.reduce(results, {0, 0, :infinity, 0, 0, :infinity, 0}, fn {time, res},
                                                                       {bugs_found, total_time,
                                                                        min_time, max_time,
                                                                        total_iter, min_iter,
                                                                        max_iter} ->
          {bugs_found, run_iters} =
            case res do
              {:bug, iter, _path_ids, _input, _res, _quality} -> {bugs_found + 1, iter}
              _ -> {bugs_found, 0}
            end

          total_iter = total_iter + run_iters

          min_iter = min(min_iter, run_iters)

          max_iter = max(max_iter, run_iters)

          total_time = total_time + time

          min_time = min(min_time, time)
          max_time = max(max_time, time)
          {bugs_found, total_time, min_time, max_time, total_iter, min_iter, max_iter}
        end)

      {name, bugs_found, total_time, min_time, max_time, total_time / length(results), total_iter,
       min_iter, max_iter, total_iter}
    end)
  end

  def print_summaries(summaries) do
    # Print header
    IO.puts(String.duplicate("-", 163))

    :io.format(
      "~-35s | ~11s | ~11s | ~11s | ~11s | ~11s | ~11s | ~11s | ~11s | ~11s~n",
      [
        "Name",
        "Bugs",
        "Total (s)",
        "Min(s)",
        "Max(s)",
        "Avg(s)",
        "Total(iter)",
        "Min(iter)",
        "Max(iter)",
        "Avg(iter)"
      ]
    )

    IO.puts(String.duplicate("-", 163))
    summaries |> Enum.each(&print_summary/1)
    IO.puts(String.duplicate("-", 163))
  end

  def print_summary(
        {name, bugs_found, total_time, min_time, max_time, avg_time, total_iter, min_iter,
         max_iter, avg_iter}
      ) do
    # Print values
    :io.format(
      "~-35s | ~11w | ~11w | ~11w | ~11w | ~11w | ~11w | ~11w | ~11w | ~11w~n",
      [
        name,
        bugs_found,
        total_time / 1_000_000,
        min_time / 1_000_000,
        max_time / 1_000_000,
        avg_time / 1_000_000,
        total_iter,
        min_iter,
        max_iter,
        avg_iter
      ]
    )
  end
end
