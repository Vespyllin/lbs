import Bitwise

defmodule Fuzzer do
  defp delete_random_character(str) do
    len = String.length(str)
    pos = :rand.uniform(len - 1)
    String.graphemes(str) |> List.delete_at(pos) |> Enum.join()
  end

  defp insert_random_printable_ascii_character(str) do
    # Printable ASCII (space to ~)
    ascii = Enum.map(32..126, fn e -> <<e>> end)
    insert_random_chararcter(str, ascii)
  end

  defp insert_random_chararcter(str, characters) do
    len = String.length(str)
    pos = :rand.uniform(len + 1) - 1
    random_char = Enum.random(characters)
    String.graphemes(str) |> List.insert_at(pos, random_char) |> Enum.join()
  end

  defp flip_random_bit(str) do
    len = String.length(str)
    pos = :rand.uniform(len) - 1
    char = String.graphemes(str) |> Enum.at(pos)
    <<char_byte::utf8>> = char
    mask = 1 <<< (:rand.uniform(8) - 1)
    flipped_char_byte = bxor(char_byte, mask)
    flipped_char = <<flipped_char_byte::utf8>>
    String.graphemes(str) |> List.replace_at(pos, flipped_char) |> Enum.join()
  end

  defp _mutate(item, n) when is_binary(item) do
    mutators = [
      &delete_random_character/1,
      &insert_random_printable_ascii_character/1,
      &flip_random_bit/1
    ]

    Enum.reduce(1..n, item, fn _, acc ->
      Enum.random(mutators).(acc)
    end)
  end

  # TODO, better mutator for numbers maybe
  defp _mutate(item, n) when is_number(item) do
    rnum = :rand.uniform()
    mutators = [
      fn x -> x + rnum end,
      fn x -> x - rnum end,
      fn x -> x * rnum end,
      fn x -> x / rnum end
    ]
    Enum.reduce(1..n, item, fn _, acc ->
      Enum.random(mutators).(acc)
    end)
  end

  defp _mutate(_item, _n) do
    raise("Not implemented")
  end

  @doc """
    Mutate input a specified number of times. Prints the result.
  """
  @spec mutate(any(), integer()) :: any()
  def mutate(items, n) when is_list(items) do
    items |> Enum.map(fn x -> _mutate(x, n) end)
  end


end
