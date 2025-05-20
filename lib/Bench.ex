require PropEl

defmodule Bench do
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

  def run(test, opts, iterations, timeout, print \\ false) do
    [time(test, opts, iterations, timeout, print)]
    |> summary()
    |> print_summaries()
  end

  def time({loc, fn_name, property}, {scheduler, mask, trim}, iterations, timeout, print) do
    # Instrument and compile target module once
    mod = PropEl.benchmark_prep(loc, fn_name)

    IO.puts(
      "Running #{iterations} fuzzing loops with" <>
        " scheduling: #{if(scheduler, do: "✔️", else: "✖️")} , masking: #{if(mask, do: "✔️", else: "✖️")} , trimming: #{if(trim, do: "✔️", else: "✖️")} ," <>
        " gated by a #{floor(timeout / 1000)}s timeout for #{to_string(fn_name)}/1."
    )

    res =
      1..iterations
      |> Task.async_stream(
        fn idx ->
          :timer.tc(fn ->
            run_with_timeout(
              fn ->
                if print do
                  IO.puts("Spawning loop #{idx}.")
                end

                res = PropEl.benchmark_runner(mod, property, scheduler, mask, trim)

                if print do
                  IO.puts("Loop #{idx} completed.")
                end

                res
              end,
              timeout
            )
          end)
        end,
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} ->
        result
      end)

    :code.purge(mod)
    :code.delete(mod)
    # IO.puts("Test case completed.")

    {to_string(fn_name), res}
  end

  def summary(suite_res) do
    suite_res
    |> Enum.map(fn {name, results} ->
      {bugs_found, total_time, min_time, max_time, total_iter, min_iter, max_iter, time_dist,
       iter_dist} =
        Enum.reduce(results, {0, 0, :infinity, 0, 0, :infinity, 0, [], []}, fn {time, res},
                                                                               {bugs_found,
                                                                                total_time,
                                                                                min_time,
                                                                                max_time,
                                                                                total_iter,
                                                                                min_iter,
                                                                                max_iter,
                                                                                time_dist,
                                                                                iter_dist} ->
          {bugs_found, run_iters, found} =
            case res do
              {:bug, iter, _path_ids, _input, _res, _quality} -> {bugs_found + 1, iter, true}
              _ -> {bugs_found, 0, false}
            end

          total_iter = total_iter + run_iters
          min_iter = min(min_iter, run_iters)
          max_iter = max(max_iter, run_iters)

          adj_time = if(found, do: time, else: 0)
          total_time = total_time + adj_time
          min_time = min(min_time, adj_time)
          max_time = max(max_time, adj_time)

          time_dist =
            if(found) do
              [time | time_dist]
            else
              time_dist
            end

          iter_dist =
            if(found) do
              [run_iters | iter_dist]
            else
              iter_dist
            end

          {bugs_found, total_time, min_time, max_time, total_iter, min_iter, max_iter, time_dist,
           iter_dist}
        end)

      {name, bugs_found, total_time, min_time, max_time, total_time / max(bugs_found, 1),
       total_iter, min_iter, max_iter, total_iter / max(bugs_found, 1), time_dist, iter_dist}
    end)
  end

  def print_summaries(summaries) do
    # Print header
    sep_len = 103
    IO.puts(String.duplicate("-", sep_len))

    :io.format(
      "~-30s | ~5s | ~6s | ~6s | ~6s | ~9s | ~9s | ~9s |~n",
      ["Name", "Bugs", "Min(s)", "Max(s)", "Avg(s)", "Min(iter)", "Max(iter)", "Avg(iter)"]
    )

    IO.puts(String.duplicate("-", sep_len))

    summaries
    |> Enum.each(fn x ->
      print_summary(x)
      {_, _, _, _, _, _, _, _, _, _, time_dist, iter_dist} = x
      IO.puts(String.duplicate("-", sep_len))

      IO.puts(
        "times: [" <>
          (time_dist
           |> Enum.map(fn x -> x / 1_000_000 end)
           |> Enum.sort()
           |> Enum.join(", ")) <> "]"
      )

      IO.puts(
        "iters: [" <>
          (iter_dist
           |> Enum.sort()
           |> Enum.join(", ")) <> "]"
      )

      IO.puts(String.duplicate("-", sep_len))
    end)
  end

  def print_summary(
        {name, bugs_found, _total_time, min_time, max_time, avg_time, _total_iter, min_iter,
         max_iter, avg_iter, _time_dist, _iter_dist}
      ) do
    t = 1_000_000

    :io.format(
      "~-30s | ~5w | ~6w | ~6w | ~6w | ~9w | ~9w | ~9w |~n",
      [
        name,
        bugs_found,
        floor(min_time / t),
        floor(max_time / t),
        floor(avg_time / t),
        min_iter,
        max_iter,
        floor(avg_iter)
      ]
    )
  end
end
