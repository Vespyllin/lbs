defmodule Blame do
  def blame(ast, cause_ids, fn_name, arity) do
    traverse(ast, {0, 0, "S"}, {cause_ids, fn_name, arity})
  end

  defp highlight(print_stmt, color) do
    prefix =
      case color do
        :red -> IO.ANSI.red()
        :blue -> IO.ANSI.blue()
        :gray -> IO.ANSI.color(1, 1, 1)
      end

    prefix <> print_stmt <> IO.ANSI.reset()
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
              "if #{Macro.to_string(condition)} do",
              if(not (cause_false or cause_true),
                do: :gray,
                else: if(cause_false, do: :blue, else: :red)
              )
            )
        )

        traverse(do_clause, {depth + 1, ctr, true_id}, config)

        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight(
              "else",
              if(not cause_false, do: :gray, else: :red)
            )
        )

        traverse(else_clause, {depth + 1, 0, false_id}, config)

        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight(
              "end",
              if(not (cause_false or cause_true),
                do: :gray,
                else: if(cause_false, do: :blue, else: :red)
              )
            )
        )

      [do: do_clause] ->
        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight(
              "if #{Macro.to_string(condition)} do",
              if(cause_true, do: :red, else: :gray)
            )
        )

        traverse(do_clause, {depth + 1, 0, true_id}, config)

        IO.puts(
          String.duplicate(" ", depth * 2) <>
            highlight("end", if(cause_true, do: :red, else: :gray))
        )
    end
  end

  defp traverse(
         {:defmodule, _meta, [{:__aliases__, __meta, _}, [mod_content]]},
         traverse_data,
         config
       ) do
    case mod_content do
      {:do, stmts} ->
        traverse(stmts, traverse_data, config)

      _ ->
        nil
    end
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

  defp traverse({decl_type, _, _}, _traverse_data, _config) when decl_type in [:def, :defp] do
    nil
  end

  defp traverse({:__block__, _, list}, {depth, _ctr, acc}, config) do
    list
    |> Enum.with_index()
    |> Enum.each(fn {element, index} ->
      traverse(element, {depth, index, acc}, config)
    end)
  end

  defp traverse(other, {depth, _, _}, _) do
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
end
