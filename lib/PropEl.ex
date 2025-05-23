require Blame
require Mutator
require Injector

defmodule PropEl do
  @disc_energy 5
  @max_string_size 32
  @discard_odds 3

  defp contained?(sublist, list) do
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

  def check_fn(mod, mutated_input, path_ids) do
    {_res, new_path_ids} = apply(mod, :hook, [[mutated_input]])
    contained?(path_ids, new_path_ids)
  end

  defp queue_server(state) do
    receive do
      :stop ->
        :ok

      {:all, caller} ->
        send(caller, {:ok, state})

      {:successful, input, mask, energy} ->
        new_state = %{state | qsucc: [{input, mask, energy}] ++ state.qsucc}
        queue_server(new_state)

      {:discard, input, mask, energy} ->
        new_state = %{state | qdisc: [{input, mask, energy}] ++ state.qdisc}
        queue_server(new_state)

      {:dequeue, caller} ->
        case state.qsucc do
          [{input, mask, energy} | rest] when energy > 1 ->
            send(caller, {:ok, input, mask, :successful})
            queue_server(%{state | qsucc: [{input, mask, energy - 1}] ++ rest})

          [{input, mask, 1} | rest] ->
            send(caller, {:ok, input, mask, :successful})
            queue_server(%{state | qsucc: rest})

          [] ->
            case state.qdisc do
              [{input, mask, energy} | rest] when energy > 1 ->
                send(caller, {:ok, input, mask, :discard})
                queue_server(%{state | qdisc: [{input, mask, energy - 1}] ++ rest})

              [{input, mask, 1} | rest] ->
                send(caller, {:ok, input, mask, :discard})
                queue_server(%{state | qdisc: rest})

              [] ->
                send(caller, nil)
                queue_server(state)
            end
        end
    end
  end

  defp coverage_server(state) do
    receive do
      :stop ->
        :ok

      {:all, caller} ->
        send(caller, {:ok, state})

      {:check, id, caller} ->
        response = if MapSet.member?(state, id), do: :seen, else: :new
        send(caller, response)
        coverage_server(state)

      {:submit, id} ->
        new_state = MapSet.put(state, id)
        coverage_server(new_state)
    end
  end

  defp dequeue(server_pid) when is_nil(server_pid) do
    {Mutator.gen(:rand.uniform(@max_string_size)), nil, :random}
  end

  defp dequeue(server_pid) do
    send(server_pid, {:dequeue, self()})

    receive do
      # Mutate only quality inputs
      {:ok, seed, seed_mask, queue} ->
        {mutation, mutated_mask} =
          if(queue == :successful,
            do: Mutator.mutate(seed, seed_mask),
            else: Mutator.havoc(seed, seed_mask)
          )

        {mutation, mutated_mask, queue}

      # Generate randomly
      nil ->
        {Mutator.gen(:rand.uniform(@max_string_size)), nil, :random}
    end
  end

  defp queue(_, path_ids, _, _, _) when length(path_ids) == 0 do
    nil
  end

  defp queue({queue_pid, coverage_pid, mod, compute_mask, do_trim}, path_ids, seed, mask, quality) do
    path_hash = Enum.join(path_ids, "/")

    # Check coverage
    send(coverage_pid, {:check, path_hash, self()})

    # Queue accordingly
    receive do
      :new ->
        seed =
          if(do_trim,
            do:
              Mutator.trim(
                fn mutated_input -> check_fn(mod, mutated_input, path_ids) end,
                seed,
                path_ids,
                @max_string_size / 2
              ),
            else: seed
          )

        mask =
          if(compute_mask,
            do: Mutator.compute_mask(fn new -> check_fn(mod, new, path_ids) end, seed),
            else: nil
          )

        send(queue_pid, {:successful, seed, mask, 2 ** (String.length(seed) + length(path_ids))})

        send(coverage_pid, {:submit, path_hash})

      :seen ->
        if(quality == :successful and :rand.uniform(@discard_odds) == @discard_odds) do
          send(queue_pid, {:discard, seed, mask, @disc_energy ** length(path_ids)})
        end
    end
  end

  defp fuzz(config, iter \\ 1)

  defp fuzz(config = {queue_pid, coverage_pid, mod, p, use_scheduler, calc_mask, do_trim}, iter) do
    # Get next input
    {input, mask, quality} = dequeue(queue_pid)

    # Run function
    {res, path_ids} = apply(mod, :hook, [[input]])

    # Continue or report bug
    if !p.(res, input) do
      {:bug, iter, path_ids, input, res, quality}
    else
      if use_scheduler do
        queue({queue_pid, coverage_pid, mod, calc_mask, do_trim}, path_ids, input, mask, quality)
      end

      fuzz(config, iter + 1)
    end
  end

  defp blue(str) do
    IO.ANSI.blue() <>
      str <>
      IO.ANSI.reset()
  end

  def propel(source_file, fn_name, p, print) do
    # Generate AST and run fuzzer
    ast =
      source_file
      |> File.read!()
      |> Code.string_to_quoted!()

    if(print) do
      IO.puts("Injecting fuzzing framework...")
    end

    mod = Injector.instrument(ast, fn_name)

    # Spawn state servers
    queue_pid = spawn_link(fn -> queue_server(%{qsucc: [], qdisc: []}) end)
    coverage_pid = spawn_link(fn -> coverage_server(MapSet.new()) end)

    if(print) do
      IO.puts("Initiating fuzzing loop...\n")
    end

    return_val =
      {:bug, iter, path_ids, input, res, quality} =
      fuzz({queue_pid, coverage_pid, mod, p, true, true, true})

    send(queue_pid, :stop)
    send(coverage_pid, :stop)

    if(print) do
      IO.puts(
        "Bug found at iter ##{iter} with " <>
          inspect(quality) <>
          " input " <>
          blue(inspect(input)) <>
          " (trimmed: " <>
          blue(
            inspect(
              Mutator.trim(
                fn mutated_input -> check_fn(mod, mutated_input, path_ids) end,
                input,
                path_ids
              )
            )
          ) <>
          ")" <>
          " yielding result:"
      )

      IO.puts(IO.ANSI.red() <> inspect(res) <> IO.ANSI.reset() <> "\n")

      if(length(path_ids) > 0) do
        IO.puts("===== Traversed Branches =====")
        Blame.blame(ast, path_ids, fn_name)
      end
    end

    return_val
  end

  def benchmark_prep(source_file, fn_name) do
    # Return module name
    source_file
    |> File.read!()
    |> Code.string_to_quoted!()
    |> Injector.instrument(fn_name)
  end

  def benchmark_runner(mod, p, use_scheduler, calc_mask, do_trim) do
    queue_pid =
      if(use_scheduler, do: spawn(fn -> queue_server(%{qsucc: [], qdisc: []}) end), else: nil)

    coverage_pid =
      if(use_scheduler, do: spawn(fn -> coverage_server(MapSet.new()) end), else: nil)

    fuzz({queue_pid, coverage_pid, mod, p, use_scheduler, calc_mask, do_trim})
  end
end
