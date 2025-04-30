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
  defp handle_fn_def([fn_name, [{:do, {:__block__, meta, [stmts]}}]]) do
    modified_body = [
      quote do
        branch_ids = []
      end,
      quote do
        try do
          unquote(stmts)
        catch
          e -> {e, branch_ids}
        end
      end,
      quote do
        branch_ids
      end
    ]

    [fn_name, [{:do, {:__block__, meta, modified_body}}]]
  end

  # Convert function to block format
  defp handle_fn_def([fn_name, [{:do, stmt}]]) do
    handle_fn_def([fn_name, [{:do, {:__block__, [], [stmt]}}]])
  end

  # Inject feedback code
  defp handle_statements() do
  end
end
