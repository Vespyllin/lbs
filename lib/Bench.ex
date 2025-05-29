require PropEl

defmodule Bench do
  defp run_with_timeout(fn_ref, timeout) do
    self = self()
    fuzzer_pid = spawn_link(fn -> send(self, fn_ref.()) end)

    receive do
      res -> res
    after
      timeout ->
        Process.exit(fuzzer_pid, :kill)
        {:timeout}
    end
  end

  def run(tests, config, iterations, timeout, conc, csv_path) do
    unless File.exists?(csv_path) do
      File.write!(
        csv_path,
        "function_name,timeout,is_schedule,is_mask,is_trim,time,iterations,queue,input_len,paths\n"
      )
    end

    IO.puts("====================== Benchmark Initiated ======================")

    tests
    |> Enum.map(fn test ->
      time(test, config, iterations, timeout, conc, csv_path)
      IO.puts("\n")
      File.write!(csv_path, "\n", [:append])
    end)

    IO.puts("\r====================== Benchmark Completed ======================\n")

    :ok
  end

  def time(
        {loc, fn_name, property},
        {scheduler, mask, trim, rotate},
        iterations,
        timeout,
        conc,
        csv_path
      ) do
    mod = PropEl.benchmark_prep(loc, fn_name)

    IO.puts(
      "\rFuzzing " <>
        ":#{to_string(fn_name)} x#{String.pad_trailing("#{iterations}", 3, " ")} @#{String.pad_trailing("#{floor(timeout / (1000 * 60))}m", 3, " ")}\t\t\t" <>
        "[S:#{if(scheduler, do: "✓", else: "✗")}] " <>
        "[M:#{if(mask, do: "✓", else: "✗")}] " <>
        "[T:#{if(trim, do: "✓", else: "✗")}] "
    )

    StatusPrinter.start_link(conc, iterations, timeout)

    1..iterations
    |> Task.async_stream(
      fn _ ->
        result =
          :timer.tc(fn ->
            run_with_timeout(
              fn ->
                StatusPrinter.inc()
                PropEl.benchmark_runner(mod, property, scheduler, mask, trim, rotate)
              end,
              timeout
            )
          end)

        case result do
          {time, {:bug, iter, input, quality, paths}} ->
            StatusPrinter.terminate()

            csv_line =
              Enum.join(
                [
                  to_string(fn_name),
                  div(timeout, 1000),
                  scheduler,
                  mask,
                  trim,
                  div(time, 1_000_000),
                  iter,
                  quality,
                  String.length(input),
                  paths
                ],
                ","
              )

            File.write!(csv_path, csv_line <> "\n", [:append])
            :write

          _ ->
            StatusPrinter.timeout()
            :noop
        end
      end,
      max_concurrency: conc,
      timeout: :infinity
    )
    |> Enum.reject(fn _ -> true end)

    :code.purge(mod)
    :code.delete(mod)
    StatusPrinter.exit()

    {to_string(fn_name), :done}
  end
end

defmodule StatusPrinter do
  use GenServer
  @offset 2 * 60 * 60 * 1000

  def start_link(conc, iters, time) do
    GenServer.start_link(
      __MODULE__,
      %{
        increments: 0,
        terminations: 0,
        timeouts: 0,
        active: 0,
        conc: conc,
        max: iters,
        start: DateTime.add(DateTime.utc_now(), @offset, :millisecond),
        end:
          DateTime.add(
            DateTime.utc_now(),
            ceil(iters / conc) * time + @offset,
            :millisecond
          ),
        time: time
      },
      name: __MODULE__
    )
  end

  def inc, do: GenServer.cast(__MODULE__, :inc)
  def terminate, do: GenServer.cast(__MODULE__, :terminate)
  def timeout, do: GenServer.cast(__MODULE__, :timeout)
  def exit, do: GenServer.cast(__MODULE__, :exit)

  # Server Callbacks
  @impl true
  def init(state) do
    print_state(state)
    {:ok, state}
  end

  @impl true
  def handle_cast(:inc, state) do
    procs_left = state.max - (state.terminations + state.timeouts)

    end_time =
      if(rem(procs_left, state.conc) == 0,
        do:
          DateTime.add(
            DateTime.utc_now(),
            floor(procs_left / state.conc) * state.time + @offset,
            :millisecond
          ),
        else: state.end
      )

    new_state = %{
      state
      | increments: state.increments + 1,
        active: state.active + 1,
        end: end_time
    }

    print_state(new_state)
    {:noreply, new_state}
  end

  def handle_cast(:terminate, state) do
    new_state = %{
      state
      | terminations: state.terminations + 1,
        active: state.active - 1
    }

    print_state(new_state)
    {:noreply, new_state}
  end

  def handle_cast(:timeout, state) do
    new_state = %{
      state
      | timeouts: state.timeouts + 1,
        active: state.active - 1
    }

    print_state(new_state)
    {:noreply, new_state}
  end

  def handle_cast(:exit, state) do
    IO.write("\n")
    {:stop, :normal, state}
  end

  defp print_state(state) do
    start_time = state.start |> to_string() |> String.slice(11..18)
    end_time = state.end |> to_string() |> String.slice(11..18)

    IO.write(
      "\r#{String.pad_trailing("#{state.increments}/#{state.max} ->", 10, " ")} " <>
        "#{IO.ANSI.green()}#{state.terminations}#{IO.ANSI.reset()} " <>
        "-- #{IO.ANSI.red()}#{state.timeouts}#{IO.ANSI.reset()} " <>
        "(#{IO.ANSI.color(1, 1, 1)}#{state.terminations + state.timeouts}#{IO.ANSI.reset()}) | " <>
        "#{IO.ANSI.blue()}#{state.active}#{IO.ANSI.reset()} " <>
        "\t(#{IO.ANSI.green()}Start:#{IO.ANSI.reset()} #{start_time}) " <>
        "(#{IO.ANSI.blue()}End:#{IO.ANSI.reset()} #{end_time})"
    )
  end
end
