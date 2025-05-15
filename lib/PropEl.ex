defmodule PropEl do
  @succ_energy 2500
  @disc_energy 500
  @mutation_count 50
  @fuzz_atoms [:fuzz_number, :fuzz_string]

  defp queue_server(state) do
    receive do
      {:successful, inputs, mask, energy} ->
        new_state = %{state | qsucc: state.qsucc ++ [{inputs, mask, energy}]}
        queue_server(new_state)

      {:discard, inputs, energy} ->
        new_state = %{state | qdisc: state.qdisc ++ [{inputs, energy}]}
        queue_server(new_state)

      {:dequeue, caller} ->
        case state.qsucc do
          [{inputs, mask, energy} | rest] when energy > 1 ->
            send(caller, {:ok, inputs, mask})
            queue_server(%{state | qsucc: [{inputs, mask, energy - 1} | rest]})

          [{inputs, mask, 1} | rest] ->
            send(caller, {:ok, inputs, mask})
            queue_server(%{state | qsucc: rest})

          [] ->
            case state.qdisc do
              [{inputs, energy} | rest] when energy > 1 ->
                send(caller, {:ok, inputs, nil})
                queue_server(%{state | qdisc: [{inputs, energy - 1} | rest]})

              [{inputs, 1} | rest] ->
                send(caller, {:ok, inputs, nil})
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

  def contained?(sublist, list) do
    sublist_length = length(sublist)
    list_length = length(list)

    if sublist_length > list_length do
      false
    else
      Enum.any?(0..(list_length - sublist_length), fn i ->
        Enum.slice(list, i, sublist_length) == sublist
      end)
    end
  end

  defp compute_mask(mod, path_ids, input) when is_binary(input) do
    for index <- 0..String.length(input) do
      mutation_res = [
        flip: Fuzzer.flip_char_at(input, index),
        insert: Fuzzer.insert_char_at(input, index),
        delete: Fuzzer.delete_char_at(input, index)
      ]

      Enum.filter(
        mutation_res,
        fn {_op, mutated_input} ->
          {_res, new_path_ids} = apply(mod, :hook, [[mutated_input]])
          contained?(path_ids, new_path_ids)
        end
      )
      |> Enum.map(fn {op, _inputs} -> op end)
    end
  end

  defp fuzz_loop(config, iter \\ -1)

  defp fuzz_loop(_, 0), do: {:no_bug}

  defp fuzz_loop(config = {queue_pid, coverage_pid, mod, input_type, p}, iter) do
    # Get next input
    send(queue_pid, {:dequeue, self()})

    input =
      receive do
        # Mutate only those inputs we're fuzzing
        {:ok, recv_input, mask} ->
          Fuzzer.mutate(recv_input, @mutation_count, mask)

        # Generate randomly
        nil ->
          Fuzzer.gen(input_type)
      end

    # Run function
    {res, path_ids} = apply(mod, :hook, [[input]])

    # Generate path hash (TODO: look into sophistication)
    path_hash = Enum.join(path_ids, "/")

    # Check property
    if !p.(res, input) do
      {:bug, iter, path_ids, input, res}
    else
      # Check coverage
      send(coverage_pid, {:check, path_hash, self()})

      # Queue accordingly
      receive do
        :new ->
          mask = compute_mask(mod, path_ids, input)
          send(queue_pid, {:successful, input, mask, @succ_energy})
          send(coverage_pid, {:submit, path_hash})

        :seen ->
          send(queue_pid, {:discard, input, @disc_energy})
      end

      fuzz_loop(config, iter - 1)
    end
  end

  def handle(source_file, fn_name, arity, input_type, p, max_iter \\ -1) do
    unless arity == 1 do
      IO.puts(IO.ANSI.red() <> "Can only fuzz functions with 1 parameter." <> IO.ANSI.reset())

      System.halt(1)
    end

    unless input_type in @fuzz_atoms do
      fuzz_atoms_str = Enum.map_join(@fuzz_atoms, ", ", &":#{&1}")

      IO.puts(
        "" <>
          IO.ANSI.red() <>
          "Select an input type from the following options: [#{fuzz_atoms_str}]" <>
          IO.ANSI.reset()
      )

      System.halt(1)
    end

    # Instrument fuzzing framework
    ast =
      source_file
      |> File.read!()
      |> Code.string_to_quoted!()

    IO.puts("Injecting fuzzing framework...")
    mod = Injector.instrument(ast, fn_name, arity)

    # Spawn state servers
    queue_pid = spawn(fn -> queue_server(%{qsucc: [], qdisc: []}) end)
    coverage_pid = spawn(fn -> coverage_server(MapSet.new()) end)

    # Return results
    IO.puts("Initiating fuzzing loop...")
    res = fuzz_loop({queue_pid, coverage_pid, mod, input_type, p})

    case res do
      {:bug, iter, path_ids, input, res} ->
        IO.puts(
          "Bug found at iter ##{if iter < 0, do: 0 - iter, else: max_iter - iter} with input \"#{input}\"."
        )

        IO.puts(inspect(res))
        Blame.blame(ast, path_ids, fn_name, arity)

      {:no_bug} ->
        IO.puts("No bugs found after #{max_iter} iterations.")
    end
  end
end
