defmodule Injector do
  @fuzz_target :fuzz_target

  def instrument(ast, fn_name) do
    [{mod_name, _}] =
      ast
      |> handle_ast({fn_name, 1})
      |> Code.compile_quoted()

    mod_name
  end

  def out(source_file, fn_name, dest_path \\ nil, source_code \\ false) do
    try do
      unless !dest_path || File.dir?(dest_path),
        do: raise("2nd argument must be an existing directory.")

      unless String.ends_with?(source_file, ".ex"),
        do: raise("Source must be a .ex file.")

      file_name = Path.basename(source_file, ".ex")
      read_res = File.read!(source_file)
      ast = Code.string_to_quoted!(read_res)

      modified_ast = handle_ast(ast, {fn_name, 1})

      [{mod_name, binary}] = Code.compile_quoted(modified_ast)
      IO.puts("Modified file compiled and loaded into the environment as \"#{mod_name}\".")

      if dest_path do
        if source_code do
          dest_file_path = "#{dest_path}/#{file_name}_fuzz.ex"

          File.write!(dest_file_path, Macro.to_string(modified_ast))

          IO.puts("Modified source code written to \"#{dest_file_path}\".")
        else
          dest_file_path = "#{dest_path}/#{mod_name}.beam"

          File.write!(dest_file_path, binary)

          IO.puts("BEAM written to \"#{dest_file_path}\".")
        end
      end
    rescue
      e in File.Error ->
        case e.reason do
          :enoent ->
            exit("Could not read from \"#{source_file}\"")

          _ ->
            exit("File error:\n#{e}")
        end

      e in SyntaxError ->
        exit("Source file contains invalid syntax.\n#{e.description}")

      e in TokenMissingError ->
        exit("Source file contains invalid syntax.\n#{e.description}")

      reason ->
        exit(reason)
    end
  end

  # Handle imports and module definitions
  defp handle_ast({:__block__, meta, file_contents}, fn_data) do
    {:__block__, meta, handle_mod_def(file_contents, fn_data)}
  end

  defp handle_ast(stmt, fn_data) do
    [res] = handle_mod_def([stmt], fn_data)
    res
  end

  # Handle module declarations
  defp handle_mod_def(nodes, fn_data) when is_list(nodes) do
    Enum.map(nodes, fn
      {:defmodule, meta, [alias_data, [mod_content]]} ->
        {:defmodule, meta, [alias_data, [handle_mod_block(mod_content, fn_data)]]}

      other ->
        other
    end)
  end

  defp handle_mod_def(pass, _), do: pass

  # Handle module content block
  defp handle_mod_block({:do, {:__block__, meta, mod_stmts}}, fn_data) do
    {:do, {:__block__, meta, handle_mod_members(mod_stmts, fn_data)}}
  end

  defp handle_mod_block({:do, mod_stmt}, fn_data) do
    {:do, {:__block__, [], handle_mod_members([mod_stmt], fn_data)}}
  end

  defp handle_mod_block(pass, _) do
    pass
  end

  defp gen_hook_ast() do
    [
      quote do
        defp state_server(state) do
          receive do
            {:request, requestor_pid} ->
              send(requestor_pid, {:response, state})

            id ->
              state_server(state ++ [id])
          end
        end
      end,
      quote do
        def hook(fuzzed_params) when is_list(fuzzed_params) do
          state_pid = spawn(fn -> state_server([]) end)

          res = apply(__MODULE__, unquote(@fuzz_target), fuzzed_params ++ [state_pid])

          send(state_pid, {:request, self()})

          receive do
            {:response, list} -> {res, list}
          end
        end
      end
    ]
  end

  # Handle module components
  defp handle_mod_members(stmts, fn_data) when is_list(stmts) do
    (gen_hook_ast() ++
       Enum.map(stmts, fn
         {decl_type, meta, fn_decl} when decl_type in [:def, :defp] ->
           case handle_fn_def(fn_decl, fn_data) do
             {:hit, modified_fn} ->
               [{decl_type, meta, modified_fn}, {decl_type, meta, fn_decl}]

             {:miss, _} ->
               {decl_type, meta, fn_decl}
           end

         other ->
           other
       end))
    |> List.flatten()
  end

  defp handle_mod_members(stmts, fn_data) do
    [
      gen_hook_ast()
      | case stmts do
          {decl_type, meta, fn_decl} when decl_type in [:def, :defp] ->
            {decl_type, meta, handle_fn_def(fn_decl, fn_data)}

          other ->
            other
        end
    ]
  end

  # Unravel functions
  defp handle_fn_def(
         [{:when, guard_meta, [{fn_name, meta, params} | guard]}, [do: stmt]],
         {fn_name, arity}
       )
       when length(params) == arity do
    IO.inspect("==================================")

    {:hit, [new_decl, new_block]} =
      handle_fn_def([{fn_name, meta, params}, [do: stmt]], {fn_name, arity})

    {:hit, [{:when, guard_meta, [new_decl | guard]}, new_block]}
  end

  defp handle_fn_def([{fn_name, meta, params}, [do: stmt]], {fn_name, arity})
       when length(params) == arity do
    new_stmts = traverse_statements(stmt, {0, "S"})

    modified_body =
      quote do
        try do
          unquote(new_stmts)
        rescue
          e -> e
        end
      end

    state_pid_var = Macro.var(if(new_stmts == stmt, do: :_state_pid, else: :state_pid), nil)

    {:hit,
     [
       {@fuzz_target, meta, params ++ [state_pid_var]},
       [do: {:__block__, meta, [modified_body]}]
     ]}
  end

  defp handle_fn_def(pass, _) do
    {:miss, pass}
  end

  # Inject feedback code
  defp traverse_statements(stmts, {_ctr, id}) when is_list(stmts) do
    stmts
    |> Enum.with_index()
    |> Enum.map(fn {stmt, idx} ->
      handle_statement(stmt, {idx + 1, id})
    end)
  end

  defp traverse_statements({:__block__, meta, stmts}, tracking_data) do
    {:__block__, meta, traverse_statements(stmts, tracking_data)}
  end

  defp traverse_statements(pass, {ctr, id}) do
    handle_statement(pass, {ctr + 1, id})
  end

  defp suffix(id, ctr, tag) do
    "#{id}-#{ctr}#{tag}"
  end

  # Injection Sites
  defp handle_statement({cond_atom, meta, [cond_stmt, clauses]}, {ctr, id})
       when cond_atom in [:if, :unless] do
    tag_prefix = if(cond_atom == :unless, do: "U", else: "")

    injected_clauses =
      case clauses do
        [do: do_clause, else: else_clause] ->
          [
            do: inject_do(do_clause, {0, suffix(id, ctr, tag_prefix <> "T")}),
            else: inject_do(else_clause, {0, suffix(id, ctr, tag_prefix <> "F")})
          ]

        [do: do_clause] ->
          [do: inject_do(do_clause, {0, suffix(id, ctr, tag_prefix <> "T")})]
      end

    {cond_atom, meta, [cond_stmt, injected_clauses]}
  end

  defp handle_statement({:with, meta, matchers_and_fallbacks}, {ctr, id}) do
    modified_matchers_and_fallbacks =
      matchers_and_fallbacks
      |> Enum.map(fn matcher_or_fallback ->
        case matcher_or_fallback do
          {:<-, meta, clause} ->
            {:<-, meta, clause}

          [do: do_clause] ->
            [do: inject_do(do_clause, {0, suffix(id, ctr, "WT")})]

          [do: do_clause, else: else_branches] ->
            [
              do: inject_do(do_clause, {0, suffix(id, ctr, "WT")}),
              else:
                else_branches
                |> Enum.with_index()
                |> Enum.map(fn {branch, idx} ->
                  handle_statement(branch, {0, suffix(id, ctr, "WF" <> to_string(idx + 1))})
                end)
            ]
        end
      end)

    {:with, meta, modified_matchers_and_fallbacks}
  end

  defp handle_statement({:case, meta, [cond_stmt, [{:do, branches}]]}, {ctr, id}) do
    modified_branches =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        handle_statement(branch, {0, suffix(id, ctr, "C" <> to_string(idx + 1))})
      end)

    {:case, meta, [cond_stmt, [{:do, modified_branches}]]}
  end

  defp handle_statement({:cond, meta, [[{:do, branches}]]}, {ctr, id}) do
    modified_branches =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        handle_statement(branch, {0, suffix(id, ctr, "O" <> to_string(idx + 1))})
      end)

    {:cond, meta, [[{:do, modified_branches}]]}
  end

  defp handle_statement({:receive, meta, [[do: branches]]}, {ctr, id}) do
    modified_branches =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        handle_statement(branch, {0, suffix(id, ctr, "R" <> to_string(idx + 1))})
      end)

    {:receive, meta, [[do: modified_branches]]}
  end

  defp handle_statement({:receive, meta, [[do: branches, after: after_branches]]}, {ctr, id}) do
    modified_branches =
      branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        handle_statement(branch, {0, suffix(id, ctr, "R" <> to_string(idx + 1))})
      end)

    modified_after_branches =
      after_branches
      |> Enum.with_index()
      |> Enum.map(fn {branch, idx} ->
        handle_statement(branch, {0, suffix(id, ctr, "A" <> to_string(idx + 1))})
      end)

    {:receive, meta, [[do: modified_branches, after: modified_after_branches]]}
  end

  defp handle_statement({:->, meta, [matcher, clause]}, {ctr, id}) do
    {:->, meta, [matcher, inject_do(clause, {ctr, id})]}
  end

  defp handle_statement(pass, _) do
    pass
  end

  # Injection Logic
  defp inject_do({:__block__, meta, stmts}, tracking_data = {_ctr, id}) do
    state_pid_var = Macro.var(:state_pid, nil)

    injection =
      quote do
        send(unquote(state_pid_var), unquote(id))
      end

    {:__block__, meta, [injection | traverse_statements(stmts, tracking_data)]}
  end

  defp inject_do(stmt, tracking_data = {_ctr, id}) do
    state_pid_var = Macro.var(:state_pid, nil)

    quote do
      send(unquote(state_pid_var), unquote(id))

      unquote(traverse_statements(stmt, tracking_data))
    end
  end
end
