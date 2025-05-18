require PropEl

defmodule Bench do

  def time({loc, fun_name, input_type, property}, iterations \\ 5) do
    res = Enum.reduce(1..iterations, [], fn _el, acc ->
        {time, res} = :timer.tc(&PropEl.propel/5, [loc, fun_name, 1, input_type, property])
        [{res, time} | acc]
    end)
    {Path.basename(loc, ".ex") <> "::" <> to_string(fun_name), res}
  end

  def test_suite(suite, iterations \\ 5) do
    suite |> Enum.map(fn test_case -> time(test_case, iterations) end) |> summary() |> print_summaries()
  end

  def print_summaries(summaries) do
    # Print header
  IO.puts("\n" <> String.duplicate("-", 105))
  :io.format(
    "~-40s | ~10s | ~10s | ~10s | ~10s | ~10s~n",
    ["Name", "Bugs", "Total", "Min", "Max", "Avg"]
  )
  IO.puts("\n" <> String.duplicate("-", 105))
    summaries |> Enum.each(&print_summary/1)
  end

  def print_summary({name, bugs_found, total_time, min_time, max_time, avg_time}) do

  # Print values
  :io.format(
    "~-40s | ~10w | ~10w | ~10w | ~10w | ~10w~n",
    [name, bugs_found, total_time, min_time, max_time, avg_time]
  )
end


  def summary(suite_res) do
    suite_res |> Enum.map(fn {name, results} ->
      {bugs_found, total_time, min_time, max_time} = Enum.reduce(results, {0, 0, :infinity, 0}, fn {res, time}, {bugs_found, total_time, min_time, max_time} ->
        bugs_found = case res do
          :bug -> bugs_found + 1
          :no_bug -> bugs_found
        end
        total_time = total_time + time
        min_time = min(min_time, time)
        max_time = max(max_time, time)
        {bugs_found, total_time, min_time, max_time}
      end)

      {name, bugs_found, total_time, min_time, max_time, total_time/length(results)}
    end)
end

end
