# PropEl

**PropEl** is a coverage-guided, property-based fuzzer for the Elixir programming language. It instruments Elixir code to provide coverage feedback and verifies user-defined properties, enabling more effective bug detection than naive fuzzing approaches.

## Features

- Coverage-guided property-based fuzzing
- Support for conditionals, message passing, and basic recursion  
- Debugging tools to visualize coverage and failures

## Installation (Ubuntu)

1. **Install Elixir and Erlang**
```bash
sudo apt update
sudo apt install -y elixir
```

2. **Verify Installation**

``` bash
elixir --version
mix --version
```

3. **Usage**


You can run a demo with the script provided:

```bash
mix run demo.exs
```

Or call the code directly:

```elixir
# Fuzzing API
PropEl.propel("./dir/code.ex", :function_name, &property_function/2)
```

To output the instrumented version of a module:

```elixir
PropEl.out("./dir/code.ex", :function_name, "./dest_dir/")
```