defmodule Blame do
  def blame(ast, cause_ids, fn_name, arity) do
    traverse(ast, {0, 0, "S"}, {cause_ids, fn_name, arity})
  end

  defp suffix(id, ctr, tag) do
    "#{id}-#{ctr}#{tag}"
  end

  defp pad(depth) do
    String.duplicate(" ", depth * 2)
  end

  defp traverse(
         {cond_atom, _meta, [condition, clauses]},
         {depth, ctr, acc},
         config = {cause_ids, _, _}
       )
       when cond_atom in [:if, :unless] do
    tag_prefix = if(cond_atom == :unless, do: "U", else: "")

    true_id = suffix(acc, ctr + 1, tag_prefix <> "T")
    false_id = suffix(acc, ctr + 1, tag_prefix <> "F")

    cause_true = true_id in cause_ids
    cause_false = false_id in cause_ids

    case clauses do
      [do: do_clause, else: else_clause] ->
        {if_color, else_color} =
          case {cause_true, cause_false} do
            {true, false} -> {IO.ANSI.red(), IO.ANSI.color(1, 1, 1)}
            {false, true} -> {IO.ANSI.blue(), IO.ANSI.red()}
            _ -> {IO.ANSI.color(1, 1, 1), IO.ANSI.color(1, 1, 1)}
          end

        IO.write(if_color)

        if(cond_atom == :unless) do
          IO.puts(pad(depth) <> "unless #{Macro.to_string(condition)} do")
        else
          IO.puts(pad(depth) <> "if #{Macro.to_string(condition)} do")
        end

        IO.write(IO.ANSI.reset())

        if(not cause_true) do
          IO.write(IO.ANSI.color(1, 1, 1))
        end

        traverse(do_clause, {depth + 1, ctr, true_id}, config)
        IO.write(IO.ANSI.reset())

        IO.write(else_color)
        IO.puts(pad(depth) <> "else")
        IO.write(IO.ANSI.reset())

        if(not cause_false) do
          IO.write(IO.ANSI.color(1, 1, 1))
        end

        traverse(else_clause, {depth + 1, 0, false_id}, config)
        IO.write(IO.ANSI.reset())

        IO.write(if_color)
        IO.puts(pad(depth) <> "end")
        IO.write(IO.ANSI.reset())

      [do: do_clause] ->
        if_color =
          if(cause_true) do
            IO.ANSI.red()
          else
            IO.ANSI.color(1, 1, 1)
          end

        IO.write(if_color)
        IO.puts(pad(depth) <> "if #{Macro.to_string(condition)} do")
        IO.write(IO.ANSI.reset())

        if(not cause_true) do
          IO.write(IO.ANSI.color(1, 1, 1))
        end

        traverse(do_clause, {depth + 1, 0, true_id}, config)
        IO.write(IO.ANSI.reset())

        IO.write(if_color)
        IO.puts(pad(depth) <> "end")
        IO.write(IO.ANSI.reset())
    end
  end

  defp traverse(
         {:cond, _meta, [[{:do, branches}]]},
         {depth, ctr, acc},
         config = {cause_ids, _, _}
       ) do
    branch_ids =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        suffix(acc, ctr + 1, "O" <> to_string(idx + 1))
      end)

    cause = Enum.any?(branch_ids, fn x -> x in cause_ids end)

    if cause do
      IO.write(IO.ANSI.blue())
    end

    IO.puts(pad(depth) <> "cond do")
    IO.write(IO.ANSI.reset())

    branches
    |> Enum.with_index()
    |> Enum.map(fn {branch, idx} ->
      branch_id = Enum.at(branch_ids, idx)

      if(branch_id in cause_ids) do
        IO.write(IO.ANSI.red())
      else
        IO.write(IO.ANSI.color(1, 1, 1))
      end

      traverse(branch, {depth + 1, 0, branch_id}, config)
      IO.write(IO.ANSI.reset())
    end)

    if cause do
      IO.write(IO.ANSI.blue())
    end

    IO.puts(pad(depth) <> "end")
    IO.write(IO.ANSI.reset())
  end

  defp traverse(
         {:case, _meta, [condition, [{:do, branches}]]},
         {depth, ctr, acc},
         config = {cause_ids, _, _}
       ) do
    branch_ids =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        suffix(acc, ctr + 1, "C" <> to_string(idx + 1))
      end)

    cause = Enum.any?(branch_ids, fn x -> x in cause_ids end)

    if cause do
      IO.write(IO.ANSI.blue())
    end

    IO.puts(pad(depth) <> "case #{Macro.to_string(condition)} do")
    IO.write(IO.ANSI.reset())

    branches
    |> Enum.with_index()
    |> Enum.map(fn {branch, idx} ->
      branch_id = Enum.at(branch_ids, idx)

      if(branch_id in cause_ids) do
        IO.write(IO.ANSI.red())
      else
        IO.write(IO.ANSI.color(1, 1, 1))
      end

      traverse(branch, {depth + 1, 0, branch_id}, config)
      IO.write(IO.ANSI.reset())
    end)

    if cause do
      IO.write(IO.ANSI.blue())
    end

    IO.puts(pad(depth) <> "end")
    IO.write(IO.ANSI.reset())
  end

  defp traverse({:->, _meta, [[matcher], clause]}, {depth, ctr, acc}, config = {cause_ids, _, _}) do
    IO.puts(
      pad(depth) <>
        Macro.to_string(matcher) <> " -> "
    )

    traverse(clause, {depth + 1, ctr, acc}, config)
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
      pad(depth) <>
        IO.ANSI.green() <> "def #{Macro.to_string(head)} do" <> IO.ANSI.reset()
    )

    traverse(body, {depth + 1, 0, acc}, config)

    IO.puts(
      pad(depth) <>
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
        IO.puts(pad(depth) <> Macro.to_string(stmt))
    end
  end
end
