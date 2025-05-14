defmodule Blame do
  def blame(ast, cause_ids, fn_name, arity) do
    traverse(ast, {0, 0, "S"}, {cause_ids, fn_name, arity})
  end

  defp highlight(print_stmt, responsible, neutral \\ false) do
    if responsible do
      if neutral do
        IO.ANSI.blue() <> print_stmt <> IO.ANSI.reset()
      else
        IO.ANSI.red() <> print_stmt <> IO.ANSI.reset()
      end
    else
      print_stmt
    end
  end

  defp highlight(print_stmt, responsible, color \\ :red) do
    if responsible do
      prefix =
        case color do
          :red ->
            IO.ANSI.red()

          :blue ->
            IO.ANSI.blue()

          :gray ->
            IO.ANSI.gray()
        end

      prefix <>
        print_stmt <>
        IO.ANSI.reset()
    else
      print_stmt
    end
  end

  defp traverse(
         {:if, _meta, [condition, clauses]},
         {depth, ctr, acc},
         config = {cause_ids, _, _}
       ) do
    true_id = "#{acc}-#{ctr + 1}T"
    false_id = "#{acc}-#{ctr + 1}F"
    cause_true = true_id in cause_ids
    cause_false = false_id in cause_ids

    case clauses do
      [do: do_clause, else: else_clause] ->
        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight(
              "if #{Macro.to_string(condition)} do #" <> true_id,
              cause_true or cause_false,
              cause_false
            )
        )

        traverse(do_clause, {depth + 1, ctr, true_id}, config)

        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight("else #" <> false_id, cause_false)
        )

        traverse(else_clause, {depth + 1, 0, false_id}, config)

        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight("end", cause_true or cause_false, cause_false)
        )

      [do: do_clause] ->
        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight("if #{Macro.to_string(condition)} do #" <> true_id, cause_true)
        )

        traverse(do_clause, {depth + 1, 0, true_id}, config)

        IO.puts(String.duplicate(" ", depth * 2) <> highlight("end", cause_true))
    end
  end

  defp traverse(
         {:defmodule, _meta, [{:__aliases__, __meta, [name]}, [mod_content]]},
         {depth, _ctr, _acc},
         config
       ) do
    # IO.puts("defmodule #{inspect(name)} do")

    case mod_content do
      {:do, stmts} ->
        traverse(stmts, {depth, 0, "S"}, config)

      _ ->
        nil
        # IO.inspect("===")
        # IO.inspect(mod_content)
    end

    # IO.puts("end")
  end

  defp traverse(
         {decl_type, _meta, [head = {fn_name, __meta, params}, [do: body]]},
         {depth, _ctr, acc},
         config = {_, fn_name, arity}
       )
       when decl_type in [:def, :defp] and length(params) == arity do
    IO.puts(
      String.duplicate(" ", depth * 2) <>
        IO.ANSI.green() <> "def #{Macro.to_string(head)} do" <> IO.ANSI.reset()
    )

    traverse(body, {depth + 1, 0, acc}, config)

    IO.puts(
      String.duplicate(" ", depth * 2) <>
        IO.ANSI.green() <> "end" <> IO.ANSI.reset()
    )
  end

  defp traverse(
         stmt = {decl_type, _meta, _},
         {depth, _ctr, _acc},
         _config
       )
       when decl_type in [:def, :defp] do
    walk(stmt, depth)
  end

  defp traverse({:__block__, _, list}, {depth, _ctr, acc}, config) do
    list
    |> Enum.with_index()
    |> Enum.each(fn {element, index} ->
      traverse(element, {depth, index, acc}, config)
    end)
  end

  defp traverse(other, {depth, _, acc}, {cause_ids, _, _}) do
    case other do
      {:@, _, _} ->
        nil

      stmt ->
        IO.puts(
          String.duplicate(" ", depth * 2) <>
            "#{Macro.to_string(stmt)}"
        )
    end
  end

  defp walk(x, depth) do
    # padding = String.duplicate(" ", depth * 2)

    # Macro.to_string(x)
    # |> String.split("\n")
    # |> Enum.map(&"#{padding}#{&1}")
    # |> Enum.join("\n")
    # |> IO.puts()
  end
end
