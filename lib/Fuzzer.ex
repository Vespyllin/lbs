defmodule Fuzzer do
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
    |> List.insert_at(index, char)
    |> Enum.join()
  end

  defp randomize_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    random_char = <<:rand.uniform(94) + 31>>

    String.graphemes(str)
    |> List.replace_at(index, random_char)
    |> Enum.join()
  end

  def mutate(input, n, mask) when is_binary(input) do
    full_mask = [:flip, :insert, :delete]

    mutators = %{
      flip: &randomize_char_at/2,
      insert: &insert_char_at/2,
      delete: &delete_char_at/2
    }

    {mutated_input, _} =
      Enum.reduce(1..n, {input, mask}, fn _, {acc_input, acc_mask} ->
        graphemes = String.graphemes(acc_input)

        Enum.with_index(graphemes)
        |> Enum.reduce({acc_input, acc_mask}, fn {_, idx}, {curr_input, curr_mask} ->
          allowed =
            if curr_mask do
              Enum.at(curr_mask, idx, [])
            else
              [Enum.random(full_mask)]
            end

          if allowed == [] do
            {curr_input, curr_mask}
          else
            mutator_key = Enum.random(allowed)
            mutator = Map.get(mutators, mutator_key)

            new_input = mutator.(curr_input, idx)

            new_mask =
              if curr_mask do
                case mutator_key do
                  :insert ->
                    List.insert_at(curr_mask, idx, full_mask)

                  :delete ->
                    List.delete_at(curr_mask, idx)

                  _ ->
                    curr_mask
                end
              else
                nil
              end

            {new_input, new_mask}
          end
        end)
      end)

    mutated_input
  end

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

        case random_ok_to_mutate(curr_mask, mutation) do
          nil ->
            {curr_input, curr_mask}

          idx ->
            mutator = Map.get(mutators, mutation)
            new_input = mutator.(curr_input, idx)

            new_mask =
              case {curr_mask, mutation} do
                {nil, _} -> curr_mask
                {_, :insert} -> List.insert_at(curr_mask, idx, full_mask)
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
