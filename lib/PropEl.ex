defmodule PropEl do
  @max_iter 100_000
  @succ_energy 2500
  @disc_energy 500
  @mutation_amp 50
  @default_input_size 64
  @fuzz_atoms [:fuzz_number, :fuzz_string]

  defp queue_server(state) do
    receive do
      {:successful, id, energy} ->
        new_state = %{state | qsucc: state.qsucc ++ [{id, energy}]}
        queue_server(new_state)

      {:discard, id, energy} ->
        new_state = %{state | qdisc: state.qdisc ++ [{id, energy}]}
        queue_server(new_state)

      {:dequeue, caller} ->
        case state.qsucc do
          [{id, energy} | rest] when energy > 1 ->
            send(caller, {:ok, id})
            queue_server(%{state | qsucc: [{id, energy - 1} | rest]})

          [{id, 1} | rest] ->
            send(caller, {:ok, id})
            queue_server(%{state | qsucc: rest})

          [] ->
            case state.qdisc do
              [{id, energy} | rest] when energy > 1 ->
                send(caller, {:ok, id})
                queue_server(%{state | qdisc: [{id, energy - 1} | rest]})

              [{id, 1} | rest] ->
                send(caller, {:ok, id})
                queue_server(%{state | qdisc: rest})

              [] ->
                send(caller, nil)
                queue_server(state)
            end
        end

      :stop ->
        :ok
    end
  end

  defp coverage_server(state) do
    receive do
      {:check, id, caller} ->
        response = if MapSet.member?(state, id), do: :seen, else: :new
        send(caller, response)
        coverage_server(state)

      {:submit, id} ->
        new_state = MapSet.put(state, id)
        coverage_server(new_state)

      :stop ->
        :ok
    end
  end

  defp fuzz_loop(_, 0, _), do: {:no_bug}

  defp fuzz_loop(config = {queue_pid, coverage_pid, mod, input_spec, p}, iter, input) do
    # Run function
    {res, path_ids} = apply(mod, :hook, [input])

    # Generate path hash (TODO: look into sophistication)
    path_hash = Enum.join(path_ids, "/")

    # Check property
    if !p.(res) do
      {:bug, iter, path_hash, res}
    else
      # Check coverage
      send(coverage_pid, {:check, path_hash, self()})

      # Queue accordingly
      receive do
        :new ->
          send(queue_pid, {:successful, input, @succ_energy})
          send(coverage_pid, {:submit, path_hash})

        :seen ->
          send(queue_pid, {:discard, input, @disc_energy})
      end

      # Get next input
      send(queue_pid, {:dequeue, self()})

      next_input =
        receive do
          # Mutate only those inputs we're fuzzing
          {:ok, recv_inputs} ->
            Enum.zip(input_spec, recv_inputs)
            |> Enum.map(fn
              {atom, val} when atom in @fuzz_atoms ->
                Fuzzer.mutate(val, @mutation_amp)

              {default_val, _} ->
                default_val
            end)

          # Generate randomly
          nil ->
            Enum.map(input_spec, fn type -> Fuzzer.gen(type, @default_input_size) end)
        end

      fuzz_loop(config, iter - 1, IO.inspect(next_input))
    end
  end

  def handle(source_file, fn_name, arity, input_spec, p) do
    unless arity > 0, do: raise("Cannot fuzz a function with no parameters.")

    unless arity == length(input_spec),
      do: raise("All function parameters must be assigned a type or value.")

    unless Enum.any?(input_spec, fn spec -> spec in @fuzz_atoms end),
      do: raise("At least 1 parameter must be specified for fuzzing.")

    # Instrument fuzzing framework
    IO.puts("Injecting fuzzing framework.")
    mod = Injector.instrument(source_file, fn_name, arity)
    IO.puts("Fuzzing framework injected.")

    # Spawn state servers
    queue_pid = spawn(fn -> queue_server(%{qsucc: [], qdisc: []}) end)
    coverage_pid = spawn(fn -> coverage_server(MapSet.new()) end)

    # Generate random initial input
    input = Enum.map(input_spec, fn type -> Fuzzer.gen(type, @default_input_size) end)

    # Return results
    IO.puts("Initiating fuzzing loop.")

    case fuzz_loop({queue_pid, coverage_pid, mod, input_spec, p}, @max_iter, input) do
      {:bug, iter, path_hash, res} ->
        IO.puts("Bug found at iter ##{@max_iter - iter} at #{path_hash}")
        IO.puts(inspect(res))

      {:no_bug} ->
        IO.puts("No bugs found.")
    end
  end
end
