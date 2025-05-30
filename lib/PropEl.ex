require Blame
require Mutator
require Injector

defmodule PropEl do
  @disc_energy 5
  @max_string_size 32
  @discard_odds 3
  # @max_queue_len 2 ** 27

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

  defp queue_server(state, on_empty, rotate) do
    receive do
      :stop ->
        :ok

      {:all, caller} ->
        send(caller, {:ok, state})

      {:successful, input, mask, energy} ->
        new_state = %{state | qsucc: [{input, mask, energy}] ++ state.qsucc}
        queue_server(new_state, on_empty, rotate)

      {:discard, input, mask, energy} ->
        # if(length(state.qdisc) > @max_queue_len,
        #   do: state.qdisc |> Enum.reverse() |> tl() |> Enum.reverse(),
        #   else: state.qdisc
        # )
        new_state = %{state | qdisc: [{input, mask, energy}] ++ state.qdisc}
        queue_server(new_state, on_empty, rotate)

      {:dequeue, caller} ->
        case state.qsucc do
          [{input, mask, energy} | rest] when energy > 1 ->
            send(caller, {:ok, input, mask, :successful})
            decr = {input, mask, energy - 1}

            new_queue = if(rotate, do: rest ++ [decr], else: [decr] ++ rest)

            queue_server(%{state | qsucc: new_queue}, on_empty, rotate)

          [{input, mask, 1} | rest] ->
            send(caller, {:ok, input, mask, :successful})
            queue_server(%{state | qsucc: rest}, on_empty, rotate)

          [] ->
            case state.qdisc do
              [{input, mask, energy} | rest] when energy > 1 ->
                send(caller, {:ok, input, mask, :discard})

                queue_server(
                  %{state | qdisc: [{input, mask, energy - 1}] ++ rest},
                  on_empty,
                  rotate
                )

              [{input, mask, 1} | rest] ->
                send(caller, {:ok, input, mask, :discard})
                queue_server(%{state | qdisc: rest}, on_empty, rotate)

              [] ->
                on_empty.()
                send(caller, nil)
                queue_server(state, on_empty, rotate)
            end
        end
    end
  end

  defp coverage_server(state, coverage) do
    receive do
      :stop ->
        :ok

      :drop ->
        coverage_server(MapSet.new(), coverage)

      {:count, caller} ->
        send(caller, {:ok, coverage |> MapSet.to_list() |> length()})
        coverage_server(state, coverage)

      {:check, "", caller} ->
        send(caller, :seen)
        coverage_server(state, coverage)

      {:check, id, caller} ->
        response = if MapSet.member?(state, id), do: :seen, else: :new
        send(caller, response)
        coverage_server(state, coverage)

      {:submit, ""} ->
        coverage_server(state, coverage)

      {:submit, id} ->
        new_state = MapSet.put(state, id)
        new_coverage = MapSet.put(state, id)

        coverage_server(new_state, new_coverage)
    end
  end

  defp dequeue(server_pid) when is_nil(server_pid) do
    {Mutator.gen(:rand.uniform(floor(@max_string_size / 2))), nil, :random}
  end

  defp dequeue(server_pid) do
    send(server_pid, {:dequeue, self()})

    receive do
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
        check_fn = fn mutant -> check_fn(mod, mutant, path_ids) end

        seed =
          if(do_trim,
            do: Mutator.trim(check_fn, seed, floor(@max_string_size / 2)),
            else: seed
          )

        mask =
          if(compute_mask,
            do: Mutator.compute_mask(fn new -> check_fn(mod, new, path_ids) end, seed),
            else: nil
          )

        energy = 100 * (2 ** String.length(seed) * length(path_ids))
        # energy = 2 ** String.length(seed) * length(path_ids)

        send(queue_pid, {:successful, seed, mask, energy})

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
      else
        send(coverage_pid, {:submit, Enum.join(path_ids, "/")})
      end

      fuzz(config, iter + 1)
    end
  end

  defp blue(str) do
    IO.ANSI.blue() <>
      str <>
      IO.ANSI.reset()
  end

  def out(source_file, fn_name, out_dir) do
    Injector.out(source_file, fn_name, out_dir)
  end

  def propel(source_file, fn_name, p) do
    # Generate AST and run fuzzer
    ast =
      source_file
      |> File.read!()
      |> Code.string_to_quoted!()

    IO.puts("Injecting fuzzing framework...")

    mod = Injector.instrument(ast, fn_name)

    # Spawn state servers
    coverage_pid = spawn_link(fn -> coverage_server(MapSet.new(), MapSet.new()) end)

    queue_pid =
      spawn_link(fn ->
        queue_server(%{qsucc: [], qdisc: []}, fn -> send(coverage_pid, :drop) end, true)
      end)

    IO.puts("Initiating fuzzing loop...\n")

    return_val =
      {:bug, iter, path_ids, input, res, quality} =
      fuzz({queue_pid, coverage_pid, mod, p, true, true, true})

    send(queue_pid, :stop)
    send(coverage_pid, :stop)

    IO.puts(
      "Bug found at iter ##{iter} with " <>
        inspect(quality) <>
        " input " <>
        blue(inspect(input)) <>
        " (trimmed: " <>
        blue(
          inspect(
            Mutator.trim(fn mutated_input -> check_fn(mod, mutated_input, path_ids) end, input)
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

    return_val
  end

  def benchmark_prep(source_file, fn_name) do
    # Return module name
    source_file
    |> File.read!()
    |> Code.string_to_quoted!()
    |> Injector.instrument(fn_name)
  end

  def benchmark_runner(mod, p, use_scheduler, calc_mask, do_trim, do_rotate) do
    coverage_pid = spawn_link(fn -> coverage_server(MapSet.new(), MapSet.new()) end)

    queue_pid =
      if(use_scheduler) do
        spawn_link(fn ->
          queue_server(
            %{qsucc: [], qdisc: []},
            fn -> send(coverage_pid, :drop) end,
            do_rotate
          )
        end)
      else
        nil
      end

    {:bug, iter, _, input, _, quality} =
      fuzz({queue_pid, coverage_pid, mod, p, use_scheduler, calc_mask, do_trim})

    send(coverage_pid, {:count, self()})

    paths_hit =
      receive do
        # Account for base path and branch hit
        {:ok, x} -> x + 1 + 1
      end

    if use_scheduler do
      send(queue_pid, :stop)
    end

    send(coverage_pid, :stop)

    {:bug, iter, input, quality, paths_hit}
  end
end
