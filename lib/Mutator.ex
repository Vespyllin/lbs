defmodule Mutator do
  # Strings
  defp delete_char_at(str, index) when is_binary(str) do
    str
    |> String.graphemes()
    |> List.delete_at(index)
    |> Enum.join()
  end

  defp insert_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    char = <<:rand.uniform(94) + 31>>

    str
    |> String.graphemes()
    |> List.insert_at(index + 1, char)
    |> Enum.join()
  end

  defp randomize_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    char = <<:rand.uniform(94) + 31>>

    str
    |> String.graphemes()
    |> List.replace_at(index, char)
    |> Enum.join()
  end

  def mutate(input, mask) when is_binary(input) do
    input
    |> String.graphemes()
    |> do_mutate(mask)
  end

  defp do_mutate(graphemes, mask, idx \\ 0)

  defp do_mutate(graphemes, mask, idx) when idx < length(graphemes) do
    full_mask = [:flip, :insert, :delete]

    mutators = %{
      flip: &randomize_char_at/2,
      insert: &insert_char_at/2,
      delete: &delete_char_at/2,
      none: fn str, _ -> str end
    }

    allowed = if mask, do: Enum.at(mask, idx, []), else: full_mask

    if allowed == [] do
      do_mutate(graphemes, mask, idx + 1)
    else
      mutator_key = Enum.random([:none | allowed])
      mutator = Map.get(mutators, mutator_key)

      new_input = mutator.(Enum.join(graphemes), idx) |> String.graphemes()

      new_mask =
        if mask do
          case mutator_key do
            :insert -> List.insert_at(mask, idx + 1, full_mask)
            :delete -> List.delete_at(mask, idx)
            _ -> mask
          end
        else
          nil
        end

      next_idx =
        case mutator_key do
          :delete -> idx
          # Don't mutate inserted entries
          :insert -> idx + 2
          _ -> idx + 1
        end

      do_mutate(new_input, new_mask, next_idx)
    end
  end

  defp do_mutate(graphemes, mask, _idx) do
    {Enum.join(graphemes), mask}
  end

  # Finds an index where the mutation is allowed
  def random_ok_to_mutate(mask, mutation) do
    allowed =
      mask
      |> Enum.with_index()
      |> Enum.filter(fn {m, _idx} -> mutation in m end)

    if allowed == [] do
      nil
    else
      {_m, idx} = Enum.random(allowed)
      idx
    end
  end

  def havoc(input, mask) when is_binary(input) do
    full_mask = [:flip, :insert, :delete]

    mutators = %{
      flip: &randomize_char_at/2,
      insert: &insert_char_at/2,
      delete: &delete_char_at/2
    }

    num_mutations = :rand.uniform(256)

    {mutated_input, mutated_mask} =
      Enum.reduce(1..num_mutations, {input, mask}, fn _, {curr_input, curr_mask} ->
        mutation = Enum.random(full_mask)

        mutate_idx =
          if is_nil(mask) do
            :rand.uniform(max(1, String.length(input))) - 1
          else
            random_ok_to_mutate(curr_mask, mutation)
          end

        case mutate_idx do
          nil ->
            {curr_input, curr_mask}

          idx ->
            mutator = Map.get(mutators, mutation)
            new_input = mutator.(curr_input, idx)

            new_mask =
              case {curr_mask, mutation} do
                {nil, _} -> curr_mask
                {_, :insert} -> List.insert_at(curr_mask, idx + 1, full_mask)
                {_, :delete} -> List.delete_at(curr_mask, idx)
                _ -> curr_mask
              end

            {new_input, new_mask}
        end
      end)

    {mutated_input, mutated_mask}
  end

  def gen(str_size) do
    for _ <- 1..str_size, into: "", do: <<Enum.random(32..126)>>
  end

  def compute_mask(check_fn, input) when is_binary(input) do
    for index <- 0..(String.length(input) - 1) do
      mutation_res = [
        flip: randomize_char_at(input, index),
        insert: insert_char_at(input, index),
        delete: delete_char_at(input, index)
      ]

      Enum.filter(mutation_res, fn {_op, mutated_input} -> check_fn.(mutated_input) end)
      |> Enum.map(fn {op, _inputs} -> op end)
    end
  end

  def trim(check_fn, input, min_len \\ 0) do
    masks = compute_mask(check_fn, input)

    case masks |> Enum.with_index() |> Enum.filter(fn {mask, _} -> :delete in mask end) do
      [] ->
        input

      deletable_indices ->
        index = deletable_indices |> Enum.random() |> elem(1)

        new_input = delete_char_at(input, index)

        if(String.length(new_input) <= min_len) do
          new_input
        else
          trim(check_fn, new_input, min_len)
        end
    end
  end

  def pad(_check_fn, "", target_len) do
    gen(target_len)
  end

  def pad(check_fn, input, target_len) do
    if(String.length(input) >= target_len) do
      input
    else
      masks = compute_mask(check_fn, input)

      insertable_indices =
        if(length(masks) == 0) do
          []
        else
          masks
          |> Enum.with_index()
          |> Enum.filter(fn {mask, _} -> :insert in mask end)
        end

      if(length(insertable_indices) == 0) do
        input
      else
        index =
          insertable_indices
          |> Enum.random()
          |> elem(1)

        new_input = insert_char_at(input, index)

        pad(check_fn, new_input, target_len)
      end
    end
  end
end
