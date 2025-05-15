import Bitwise

defmodule Fuzzer do
  # Strings
  def delete_char_at(str, index) when is_binary(str) do
    String.graphemes(str)
    |> List.delete_at(index)
    |> Enum.join()
  end

  def insert_char_at(str, index) when is_binary(str) do
    # Printable ASCII
    char = <<:rand.uniform(94) + 31>>

    String.graphemes(str)
    |> List.insert_at(index, char)
    |> Enum.join()
  end

  def flip_char_at(str, index) when is_binary(str) do
    # Printable ASCII 
    random_char = <<:rand.uniform(94) + 31>>

    String.graphemes(str)
    |> List.replace_at(index, random_char)
    |> Enum.join()
  end

  # Numbers
  defp flip_random_bit(num) when is_number(num) do
    random_bit_idx = :rand.uniform(get_bit_width(num)) - 1
    Bitwise.bxor(num, 1 <<< random_bit_idx)
  end

  defp get_bit_width(num) when is_number(num) do
    num
    |> abs()
    |> :binary.encode_unsigned()
    |> byte_size()
    |> Kernel.*(8)
  end

  defp flip_all_bits(num) when is_integer(num), do: Bitwise.bnot(num)

  defp div(num) when is_integer(num), do: trunc(num >>> :rand.uniform(get_bit_width(num)))

  defp mult(num) when is_integer(num), do: trunc(num <<< :rand.uniform(get_bit_width(num)))

  defp twos_complement(num) when is_integer(num), do: Bitwise.bnot(num) + 1

  defp generate_num(size), do: :rand.uniform(1 <<< size) - 1

  # Export
  def mutate(input, n, mask) when is_binary(input) do
    mutators = %{
      delete: &delete_char_at/2,
      insert: &insert_char_at/2,
      flip: &flip_char_at/2
    }

    Enum.reduce(1..n, input, fn _, acc ->
      graphemes = String.graphemes(acc)

      # Get all valid indices with their allowed mutations
      valid_indices =
        Enum.with_index(graphemes)
        |> Enum.filter(fn {_, idx} ->
          mask == nil || (idx < length(mask) && length(Enum.at(mask, idx)) > 0)
        end)

      if valid_indices == [] do
        # No valid mutations possible
        acc
      else
        {_, index} = Enum.random(valid_indices)

        # Get allowed mutations for this index (or all if mask is nil)
        allowed_mutations = if mask, do: Enum.at(mask, index), else: [:delete, :insert, :flip]

        # Choose a random allowed mutator
        mutator_key = Enum.random(allowed_mutations)
        mutator = Map.get(mutators, mutator_key)

        mutator.(acc, index)
      end
    end)
  end

  def mutate(item, n, _mask) when is_number(item) do
    mutators = [
      # &inc/1,
      # &dec/1,
      &div/1,
      &mult/1,
      &flip_all_bits/1,
      &flip_random_bit/1,
      &twos_complement/1
    ]

    Enum.reduce(1..n, item, fn _, acc ->
      Enum.random(mutators).(acc)
    end)
  end

  def gen(gen_type) do
    case gen_type do
      :fuzz_number -> generate_num(2 ** 64)
      :fuzz_string -> for _ <- 1..8, into: "", do: <<Enum.random(32..126)>>
    end
  end
end
