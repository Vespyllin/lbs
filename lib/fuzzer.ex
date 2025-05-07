import Bitwise

defmodule Fuzzer do
  # Strings
  defp delete_random_character(str) when is_binary(str) do
    len = String.length(str)
    pos = :rand.uniform(len - 1)
    String.graphemes(str) |> List.delete_at(pos) |> Enum.join()
  end

  defp insert_random_printable_ascii_character(str) when is_binary(str) do
    # Printable ASCII (space to ~)
    ascii = Enum.map(32..126, fn e -> <<e>> end)
    insert_random_chararcter(str, ascii)
  end

  defp insert_random_chararcter(str, characters) when is_binary(str) do
    len = String.length(str)
    pos = :rand.uniform(len + 1) - 1
    random_char = Enum.random(characters)
    String.graphemes(str) |> List.insert_at(pos, random_char) |> Enum.join()
  end

  defp flip_random_bit(str) when is_binary(str) do
    len = String.length(str)
    pos = :rand.uniform(len) - 1
    char = String.graphemes(str) |> Enum.at(pos)
    <<char_byte::utf8>> = char
    mask = 1 <<< (:rand.uniform(8) - 1)
    flipped_char_byte = bxor(char_byte, mask)
    flipped_char = <<flipped_char_byte::utf8>>
    String.graphemes(str) |> List.replace_at(pos, flipped_char) |> Enum.join()
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

  # defp inc(num) when is_integer(num), do: num + 1

  # defp dec(num) when is_integer(num), do: num - 1

  defp div(num) when is_integer(num), do: trunc(num >>> :rand.uniform(get_bit_width(num)))

  defp mult(num) when is_integer(num), do: trunc(num <<< :rand.uniform(get_bit_width(num)))

  defp twos_complement(num) when is_integer(num), do: Bitwise.bnot(num) + 1

  defp generate_num(size), do: :rand.uniform(1 <<< size) - 1

  # Export
  def mutate(item, n) when is_binary(item) do
    mutators = [
      &delete_random_character/1,
      &insert_random_printable_ascii_character/1,
      &flip_random_bit/1
    ]

    Enum.reduce(1..n, item, fn _, acc ->
      Enum.random(mutators).(acc)
    end)
  end

  def mutate(item, n) when is_number(item) do
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

  def mutate(items, n) when is_list(items) do
    Enum.map(items, fn x -> mutate(x, n) end)
  end

  def gen(type_or_value, size) do
    case type_or_value do
      :fuzz_number -> generate_num(32)
      :fuzz_string -> for _ <- 1..size, into: "", do: <<Enum.random(32..126)>>
      pass -> pass
    end
  end
end
