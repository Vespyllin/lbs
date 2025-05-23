require PropEl

defmodule DynamicCounter do
  use GenServer

  # Client API
  def start_link(_) do
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
    IO.puts("\n")

    {:stop, :normal, state}
  end

  # Helper to print and overwrite the line
  defp print_state(state) do
    IO.write(
      "\r#{state.increments} -> #{IO.ANSI.green()}#{state.terminations}#{IO.ANSI.reset()} -- #{IO.ANSI.red()}#{state.timeouts}#{IO.ANSI.reset()} | #{IO.ANSI.blue()}#{state.active}#{IO.ANSI.reset()} "
    )
  end
end

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

  def run(tests, opts, iterations, timeout, csv_path \\ "benchmarks.csv") do
    # Initialize CSV if not exists
    unless File.exists?(csv_path) do
      File.write!(csv_path, "function_name,timeout,is_schedule,is_mask,is_trim,time,iterations\n")
    end

    tests
    |> Enum.map(fn test ->
      time(test, opts, iterations, timeout, csv_path)
      File.write!(csv_path, "\n")
    end)

    :ok
  end

  def time({loc, fn_name, property}, {scheduler, mask, trim}, iterations, timeout, csv_path) do
    mod = PropEl.benchmark_prep(loc, fn_name)

    IO.puts(
      "Running #{iterations} fuzzing loops with" <>
        " scheduling: #{if(scheduler, do: "✔️ ", else: "✖️ ")}, masking: #{if(mask, do: "✔️ ", else: "✖️ ")}, trimming: #{if(trim, do: "✔️ ", else: "✖️ ")}, " <>
        "gated by a #{floor(timeout / 1000)}s timeout for #{to_string(fn_name)}/1."
    )

    DynamicCounter.start_link(nil)

    1..iterations
    |> Task.async_stream(
      fn idx ->
        result =
          :timer.tc(fn ->
            run_with_timeout(
              fn ->
                DynamicCounter.inc()
                PropEl.benchmark_runner(mod, property, scheduler, mask, trim)
              end,
              timeout
            )
          end)

        case result do
          {time, {:bug, iter, _, _, _, _}} ->
            DynamicCounter.terminate()

            csv_line =
              Enum.join(
                [
                  to_string(fn_name),
                  div(timeout, 1000),
                  scheduler,
                  mask,
                  trim,
                  div(time, 1_000_000),
                  iter
                ],
                ","
              )

            File.write!(csv_path, csv_line <> "\n", [:append])
            {time, result}

          _ ->
            DynamicCounter.timeout()

            :noop
        end
      end,
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Enum.reject(fn _ -> true end)

    :code.purge(mod)
    :code.delete(mod)
    DynamicCounter.exit()

    {to_string(fn_name), :done}
  end
end
