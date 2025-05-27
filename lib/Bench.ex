require PropEl

defmodule StatusPrinter do
  use GenServer

  def start_link() do
    GenServer.start_link(
      __MODULE__,
      %{
        increments: 0,
        terminations: 0,
        timeouts: 0,
        active: 0
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
    # Print initial state
    print_state(state)
    {:ok, state}
  end

  @impl true
  def handle_cast(:inc, state) do
    new_state = %{
      state
      | increments: state.increments + 1,
        active: state.active + 1
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

  # Helper to print and overwrite the line
  defp print_state(state) do
    IO.write(
      "\r#{state.increments} -> #{IO.ANSI.green()}#{state.terminations}#{IO.ANSI.reset()} -- #{IO.ANSI.red()}#{state.timeouts}#{IO.ANSI.reset()} (#{IO.ANSI.color(1, 1, 1)}#{state.terminations + state.timeouts}#{IO.ANSI.reset()}) | #{IO.ANSI.blue()}#{state.active}#{IO.ANSI.reset()} "
    )
  end
end

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

  def run(tests, opts, iterations, timeout, csv_path) do
    # Initialize CSV if not exists
    unless File.exists?(csv_path) do
      File.write!(
        csv_path,
        "function_name,timeout,is_schedule,is_mask,is_trim,rotate,time,iterations,queue,input_len,paths\n"
      )
    end

    IO.puts("===================== Benchmarks Initiated =====================")

    tests
    |> Enum.map(fn test ->
      time(test, opts, iterations, timeout, csv_path)
      File.write!(csv_path, "\n", [:append])
    end)

    IO.puts("===================== Benchmarks Completed =====================\n")

    :ok
  end

  def time(
        {loc, fn_name, property},
        {scheduler, mask, trim, rotate},
        iterations,
        timeout,
        csv_path
      ) do
    mod = PropEl.benchmark_prep(loc, fn_name)

    IO.puts(
      "\rFuzzing " <>
        "#{to_string(fn_name)}x#{iterations}@#{floor(timeout / (1000 * 60))}m\t->\t" <>
        "[sch:#{if(scheduler, do: "✓", else: "✗")}] " <>
        "[msk:#{if(mask, do: "✓", else: "✗")}] " <>
        "[trm:#{if(trim, do: "✓", else: "✗")}] " <>
        "[rot:#{if(rotate, do: "✓", else: "✗")}] "
    )

    StatusPrinter.start_link()

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
                  rotate,
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
      max_concurrency: System.schedulers_online(),
      # max_concurrency: 10,
      timeout: :infinity
    )
    |> Enum.reject(fn _ -> true end)

    :code.purge(mod)
    :code.delete(mod)
    StatusPrinter.exit()

    {to_string(fn_name), :done}
  end
end
