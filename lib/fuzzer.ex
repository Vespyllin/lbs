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

  @doc """
  Fuzz a string a specified number of times. Prints the result.
  """
  @spec fuzz(String.t(), integer()) :: any()
  def fuzz(item, n) do
    mutators = [
      &delete_random_character/1,
      &insert_random_printable_ascii_character/1,
      &flip_random_bit/1
    ]

    Enum.reduce(1..n, item, fn i, acc ->
      fun = Enum.random(mutators)
      acc = fun.(acc)
      IO.puts("#{i}: " <> "#{acc}")
      acc
    end)
  end

  def hello do
    # delete_random_character("Hello")
    # insert_random_printable_ascii_character("Hello")
    # flip_random_bit("Hello")
    # str = "Hello, I am testing my mutators. Yay!"
    # fuzz(str, 20)
    IO.inspect("Fuzzer")
  end
end
