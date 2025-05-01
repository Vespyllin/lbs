defmodule Injector do
  def handle(source_file, dest_path \\ nil, source_code \\ false) do
    try do
      unless !dest_path || File.dir?(dest_path),
        do: raise("2nd argument must be an existing directory.")

      unless String.ends_with?(source_file, ".ex"),
        do: raise("Source must be a .ex file.")

      file_name = Path.basename(source_file, ".ex")
      read_res = File.read!(source_file)

      modified_ast = handle_ast(Code.string_to_quoted!(read_res))

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
  defp handle_ast({:__block__, meta, file_contents}) do
    {:__block__, meta, handle_mod_def(file_contents)}
  end

  defp handle_ast(pass) do
    [res] = handle_mod_def([pass])
    res
  end

  # Handle module declarations
  defp handle_mod_def([{:defmodule, meta, [alias_data, [mod_content]]} | tail]) do
    [{:defmodule, meta, [alias_data, [handle_mod_block(mod_content)]]} | handle_mod_def(tail)]
  end

  defp handle_mod_def([head | tail]) do
    [head | handle_mod_def(tail)]
  end

  defp handle_mod_def(pass) do
    pass
  end

  # Handle module content block
  defp handle_mod_block({:do, {:__block__, meta, mod_stmts}}) do
    {:do, {:__block__, meta, handle_mod_members(mod_stmts)}}
  end

  defp handle_mod_block({:do, mod_stmts}) do
    {:do, handle_mod_members(mod_stmts)}
  end

  defp handle_mod_block(pass) do
    pass
  end

  # Handle module components
  defp handle_mod_members({:def, meta, fn_decl}) do
    {:def, meta, handle_fn_def(fn_decl)}
  end

  defp handle_mod_members([{:def, meta, fn_decl} | tail]) do
    [{:def, meta, handle_fn_def(fn_decl)} | handle_mod_members(tail)]
  end

  defp handle_mod_members([head | tail]) do
    [head | handle_mod_members(tail)]
  end

  defp handle_mod_members(pass) do
    pass
  end

  # Unravel functions
  defp handle_fn_def([{fn_name, meta, params}, [do: stmt]]) do
    modified_body =
      quote do
        state_pid =
          spawn(fn ->
            receive_loop = fn receive_loop, state ->
              receive do
                {:request, requestor_pid} ->
                  send(requestor_pid, {:response, state})

                id ->
                  receive_loop.(receive_loop, [id | state])
              end
            end

            receive_loop.(receive_loop, [])
          end)

        res =
          try do
            unquote(traverse_statements(stmt, 0, "S"))
          catch
            e -> e
          end

        send(state_pid, {:request, self()})

        receive do
          {:response, list} -> {res, list}
        end
      end

    [{fn_name, meta, params}, [do: {:__block__, meta, [modified_body]}]]
  end

  # Inject feedback code

  defp traverse_statements([head | tail], ctr, id) do
    [handle_statements(head, ctr, id) | traverse_statements(tail, ctr + 1, id)]
  end

  defp traverse_statements({:__block__, meta, stmts}, ctr, id) do
    {:__block__, meta, traverse_statements(stmts, ctr, id)}
  end

  defp traverse_statements([], _ctr, _id) do
    []
  end

  defp traverse_statements(pass, ctr, id) do
    handle_statements(pass, ctr + 1, id)
  end

  defp handle_statements({:if, meta, [cond_stmt, clauses]}, ctr, id) do
    injected_clauses =
      case clauses do
        [do: do_clause, else: else_clause] ->
          [
            do: inject_do(do_clause, ctr + 1, id <> "-" <> to_string(ctr) <> "T"),
            else: inject_do(else_clause, ctr + 1, id <> "-" <> to_string(ctr) <> "F")
          ]

        [do: do_clause] ->
          [do: inject_do(do_clause, ctr + 1, id <> "-" <> to_string(ctr) <> "T")]

        r ->
          raise ArgumentError, message: "UNHANDLED IF CONSTRUCT" <> to_string(r)
      end

    {:if, meta, [cond_stmt, injected_clauses]}
  end

  defp handle_statements(pass, _ctr, _id) do
    pass
  end

  defp inject_do({:__block__, meta, stmts}, ctr, id) do
    injection =
      quote do
        send(state_pid, unquote(id))
      end

    {:__block__, meta, [injection | traverse_statements(stmts, ctr, id)]}
  end

  defp inject_do(stmt, ctr, id) do
    quote do
      send(state_pid, unquote(id))

      unquote(traverse_statements(stmt, ctr, id))
    end
  end
end
