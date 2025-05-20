defmodule Mutator do
  # Strings
  defp delete_char_at(str, index) when is_binary(str) do
    String.graphemes(str)
    |> List.delete_at(index)
    |> Enum.join()
  end

  defp insert_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    char = <<:rand.uniform(94) + 31>>

    String.graphemes(str)
    |> List.insert_at(index + 1, char)
    |> Enum.join()
  end

  defp randomize_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    random_char = <<:rand.uniform(94) + 31>>

    String.graphemes(str)
    |> List.replace_at(index, random_char)
    |> Enum.join()
  end

  def mutate(input, mask, max_len) when is_binary(input) do
    do_mutate(String.graphemes(input), mask, 0, max_len)
    |> then(fn {graphemes, _mask} -> Enum.join(graphemes) end)
  end

  defp do_mutate(graphemes, mask, idx, max_len)
       when idx < length(graphemes) and length(graphemes) < max_len do
    full_mask = [:flip, :insert, :delete]

    mutators = %{
      flip: &randomize_char_at/2,
      insert: &insert_char_at/2,
      delete: &delete_char_at/2
    }

    allowed = if mask, do: Enum.at(mask, idx, []), else: [Enum.random(full_mask)]

    if allowed == [] do
      do_mutate(graphemes, mask, idx + 1, max_len)
    else
      mutator_key = Enum.random(allowed)
      mutator = Map.get(mutators, mutator_key)

      # IO.inspect({Enum.join(graphemes), mask, mutator_key, idx})

      new_input = mutator.(Enum.join(graphemes), idx) |> String.graphemes()

      new_mask =
        if mask do
          case mutator_key do
            :insert -> List.insert_at(mask, idx + 1, [:i])
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

      do_mutate(new_input, new_mask, next_idx, max_len)
    end
  end

  defp do_mutate(graphemes, mask, _idx, _max_len) do
    {graphemes, mask}
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

    {mutated_input, _} =
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

    mutated_input
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
end
