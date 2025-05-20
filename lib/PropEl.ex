require Blame
require Fuzzer
require Injector

defmodule PropEl do
  @succ_energy 1000
  @disc_energy 5
  @max_string_size 32

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

  defp trim_input(mod, input, path_ids, min_len \\ 0) do
    compute_masks = fn input ->
      Fuzzer.compute_mask(fn mutated_input -> check_fn(mod, mutated_input, path_ids) end, input)
    end

    trim_rec = fn trim_rec, current_input ->
      if(String.length(current_input) <= min_len) do
        current_input
      else
        masks = compute_masks.(current_input)

        case Enum.find_index(masks, fn mask -> :delete in mask end) do
          nil ->
            current_input

          index ->
            new_input =
              current_input
              |> String.graphemes()
              |> List.delete_at(index)
              |> Enum.join()

            trim_rec.(trim_rec, new_input)
        end
      end
    end

    trim_rec.(trim_rec, input)
  end

  def check_fn(mod, mutated_input, path_ids) do
    {_res, new_path_ids} = apply(mod, :hook, [[mutated_input]])
    contained?(path_ids, new_path_ids)
  end

  defp queue_server(state) do
    receive do
      {:successful, inputs, mask, energy} ->
        new_state = %{state | qsucc: [{inputs, mask, energy}] ++ state.qsucc}
        queue_server(new_state)

      {:discard, inputs, mask, energy} ->
        new_state = %{state | qdisc: [{inputs, mask, energy}] ++ state.qdisc}
        queue_server(new_state)

      {:all, caller} ->
        send(caller, {:ok, state})

      {:dequeue, caller} ->
        case state.qsucc do
          [{inputs, mask, energy} | rest] when energy > 1 ->
            send(caller, {:ok, inputs, mask, :successful})
            queue_server(%{state | qsucc: [{inputs, mask, energy - 1} | rest]})

          [{inputs, mask, 1} | rest] ->
            send(caller, {:ok, inputs, mask, :successful})
            queue_server(%{state | qsucc: rest})

          [] ->
            case state.qdisc do
              [{inputs, mask, energy} | rest] when energy > 1 ->
                send(caller, {:ok, inputs, mask, :discard})
                queue_server(%{state | qdisc: [{inputs, mask, energy - 1} | rest]})

              [{inputs, mask, 1} | rest] ->
                send(caller, {:ok, inputs, mask, :discard})
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

      {:all, caller} ->
        send(caller, {:ok, state})

      :stop ->
        :ok
    end
  end

  defp dequeue_input(server_pid) when is_nil(server_pid) do
    {Fuzzer.gen(:rand.uniform(@max_string_size)), nil, :random}
  end

  defp dequeue_input(server_pid) do
    send(server_pid, {:dequeue, self()})

    receive do
      # Mutate only quality inputs
      {:ok, seed, seed_mask, queue} ->
        mutation =
          if(queue == :successful,
            do: Fuzzer.mutate(seed, seed_mask),
            else: Fuzzer.havoc(seed, seed_mask)
          )

        {mutation, seed_mask, queue}

      # Generate randomly
      nil ->
        {Fuzzer.gen(:rand.uniform(@max_string_size)), nil, :random}
    end
  end

  defp queue_input(_, path_ids, _, _, _) when length(path_ids) == 0 do
    nil
  end

  defp queue_input(
         {coverage_pid, queue_pid, mod, compute_mask, trim},
         path_ids,
         input,
         seed_mask,
         quality
       ) do
    path_hash = Enum.join(path_ids, "/")

    # Check coverage
    send(coverage_pid, {:check, path_hash, self()})

    # Queue accordingly
    receive do
      :new ->
        clean_input =
          if(trim, do: trim_input(mod, input, path_ids, @max_string_size / 2), else: input)

        mask =
          if compute_mask do
            Fuzzer.compute_mask(
              fn mutated_input -> check_fn(mod, mutated_input, path_ids) end,
              clean_input
            )
          else
            nil
          end

        send(queue_pid, {:successful, clean_input, mask, @succ_energy * length(path_ids)})
        send(coverage_pid, {:submit, path_hash})

      :seen ->
        if(quality == :successful) do
          send(queue_pid, {:discard, input, seed_mask, @disc_energy * length(path_ids)})
        end
    end
  end

  defp fuzz_loop(config, iter \\ 1)

  defp fuzz_loop(config = {queue_pid, coverage_pid, mod, p, use_scheduler, calc_mask, trim}, iter) do
    # Get next input
    {input, seed_mask, quality} = dequeue_input(queue_pid)

    # Run function
    {res, path_ids} = apply(mod, :hook, [[input]])

    # Continue or report bug
    if !p.(res, input) do
      {:bug, iter, path_ids, input, res, quality}
    else
      if use_scheduler do
        queue_input(
          {coverage_pid, queue_pid, mod, calc_mask, trim},
          path_ids,
          input,
          seed_mask,
          quality
        )
      end

      fuzz_loop(config, iter + 1)
    end
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
    queue_pid = spawn(fn -> queue_server(%{qsucc: [], qdisc: []}) end)
    coverage_pid = spawn(fn -> coverage_server(MapSet.new()) end)

    if(print) do
      IO.puts("Initiating fuzzing loop...\n")
    end

    return_val =
      {:bug, iter, path_ids, input, res, quality} =
      fuzz_loop({queue_pid, coverage_pid, mod, p, true, true, true})

    if(print) do
      IO.puts(
        "Bug found at iter ##{iter} with " <>
          inspect(quality) <>
          " input " <>
          IO.ANSI.blue() <>
          inspect(input) <>
          IO.ANSI.reset() <>
          " (trimmed: " <>
          IO.ANSI.blue() <>
          inspect(trim_input(mod, input, path_ids)) <>
          IO.ANSI.reset() <>
          ")" <>
          IO.ANSI.reset() <>
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
    # return module
    source_file
    |> File.read!()
    |> Code.string_to_quoted!()
    |> Injector.instrument(fn_name)
  end

  def benchmark_runner(mod, p, use_scheduler, calc_mask, trim) do
    queue_pid =
      if(use_scheduler, do: spawn(fn -> queue_server(%{qsucc: [], qdisc: []}) end), else: nil)

    coverage_pid =
      if(use_scheduler, do: spawn(fn -> coverage_server(MapSet.new()) end), else: nil)

    fuzz_loop({queue_pid, coverage_pid, mod, p, use_scheduler, calc_mask, trim})
  end
end
