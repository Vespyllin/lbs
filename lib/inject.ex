defmodule Injector do
  def hello() do
    IO.inspect("Injector")
  end

  def handle(source_file, fn_name, arity)
      when is_atom(fn_name) and is_number(arity) do
    unless String.ends_with?(source_file, ".ex") do
      raise("Source must be a .ex file.")
    end

    IO.puts("Injecting fuzzing framework.")

    [{mod_name, _}] =
      source_file
      |> File.read!()
      |> Code.string_to_quoted!()
      |> handle_ast(fn_name, arity)
      |> Code.compile_quoted()

    IO.puts("Fuzzing framework injected.")

    mod_name
  end

  def _handle(source_file, fn_name, arity, dest_path \\ nil, source_code \\ false)
      when is_atom(fn_name) and is_number(arity) do
    try do
      unless !dest_path || File.dir?(dest_path),
        do: raise("2nd argument must be an existing directory.")

      unless String.ends_with?(source_file, ".ex"),
        do: raise("Source must be a .ex file.")

      file_name = Path.basename(source_file, ".ex")
      read_res = File.read!(source_file)

      modified_ast = handle_ast(Code.string_to_quoted!(read_res), fn_name, arity)

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
  defp handle_ast({:__block__, meta, file_contents}, fn_name, arity) do
    {:__block__, meta, handle_mod_def(file_contents, fn_name, arity)}
  end

  defp handle_ast(stmt, fn_name, arity) do
    [res] = handle_mod_def([stmt], fn_name, arity)
    res
  end

  # Handle module declarations
  defp handle_mod_def(nodes, fn_name, arity) when is_list(nodes) do
    Enum.map(nodes, fn
      {:defmodule, meta, [alias_data, [mod_content]]} ->
        {:defmodule, meta, [alias_data, [handle_mod_block(mod_content, fn_name, arity)]]}

      other ->
        other
    end)
  end

  defp handle_mod_def(pass, _, _), do: pass

  # Handle module content block
  defp handle_mod_block({:do, {:__block__, meta, mod_stmts}}, fn_name, arity) do
    {:do, {:__block__, meta, handle_mod_members(mod_stmts, fn_name, arity)}}
  end

  defp handle_mod_block({:do, mod_stmts}, fn_name, arity) do
    {:do, handle_mod_members(mod_stmts, fn_name, arity)}
  end

  defp handle_mod_block(pass, _, _) do
    pass
  end

  # Handle module components
  defp handle_mod_members(stmts, fn_name, arity) when is_list(stmts) do
    hook_ast =
      quote do
        defp state_server(state) do
          receive do
            {:request, requestor_pid} ->
              send(requestor_pid, {:response, state})

            id ->
              state_server([id | state])
          end
        end

        def hook(fuzzed_params) when is_list(fuzzed_params) do
          state_pid = spawn(fn -> state_server([]) end)

          apply(__MODULE__, unquote(fn_name), fuzzed_params ++ [state_pid])
        end
      end

    [
      hook_ast
      | Enum.map(stmts, fn
          {decl_type, meta, fn_decl} when decl_type in [:def, :defp] ->
            {decl_type, meta, handle_fn_def(fn_decl, fn_name, arity)}

          other ->
            other
        end)
    ]
  end

  defp handle_mod_members(pass, _, _), do: pass

  # Unravel functions

  defp handle_fn_def([{fn_name, meta, params}, [do: stmt]], fn_name, arity)
       when length(params) == arity do
    state_pid_var = Macro.var(:state_pid, nil)

    modified_body =
      quote do
        res =
          try do
            unquote(traverse_statements(stmt, 0, "S"))
          rescue
            e -> e
          end

        send(unquote(state_pid_var), {:request, self()})

        receive do
          {:response, list} -> {res, list}
        end
      end

    [
      {fn_name, meta, params ++ [state_pid_var]},
      [do: {:__block__, meta, [modified_body]}]
    ]
  end

  defp handle_fn_def(pass, _, _) do
    pass
  end

  # Inject feedback code
  defp traverse_statements(stmts, ctr, id) when is_list(stmts) do
    Enum.map(stmts, fn stmt -> handle_statements(stmt, ctr, id) end)
  end

  defp traverse_statements({:__block__, meta, stmts}, ctr, id) do
    {:__block__, meta, traverse_statements(stmts, ctr, id)}
  end

  defp traverse_statements(pass, ctr, id), do: handle_statements(pass, ctr + 1, id)

  defp suffix(id, ctr, tag) do
    id <> "-" <> to_string(ctr) <> tag
  end

  defp handle_statements({:if, meta, [cond_stmt, clauses]}, ctr, id) do
    injected_clauses =
      case clauses do
        [do: do_clause, else: else_clause] ->
          [
            do: inject_do(do_clause, ctr + 1, suffix(id, ctr, "T")),
            else: inject_do(else_clause, ctr + 1, suffix(id, ctr, "F"))
          ]

        [do: do_clause] ->
          [do: inject_do(do_clause, ctr + 1, suffix(id, ctr, "T"))]

        r ->
          raise ArgumentError, message: "UNHANDLED IF CONSTRUCT" <> to_string(r)
      end

    {:if, meta, [cond_stmt, injected_clauses]}
  end

  defp handle_statements(pass, _ctr, _id) do
    pass
  end

  defp inject_do({:__block__, meta, stmts}, ctr, id) do
    state_pid_var = Macro.var(:state_pid, nil)

    injection =
      quote do
        send(unquote(state_pid_var), unquote(id))
      end

    {:__block__, meta, [injection | traverse_statements(stmts, ctr, id)]}
  end

  defp inject_do(stmt, ctr, id) do
    state_pid_var = Macro.var(:state_pid, nil)

    quote do
      send(unquote(state_pid_var), unquote(id))

      unquote(traverse_statements(stmt, ctr, id))
    end
  end
end
