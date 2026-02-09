defmodule Mix.Tasks.ElixirWorkers.Dev do
  use Mix.Task

  @shortdoc "Build and start local dev server with wrangler"

  @moduledoc """
  Builds the .avm archive and starts a local development server
  using Cloudflare's wrangler CLI.

      $ mix elixir_workers.dev

  This runs `mix elixir_workers.build`, auto-applies `schema.sql`
  to the local D1 database, then starts `wrangler dev` from the
  project root (where `wrangler.jsonc` lives).
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("elixir_workers.build")

    project_root = File.cwd!()

    apply_schema(project_root)

    IO.puts("")
    IO.puts("  #{IO.ANSI.magenta()}#{IO.ANSI.bright()}elixir-workers#{IO.ANSI.reset()} #{IO.ANSI.faint()}dev#{IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.cyan()}http://localhost:8797#{IO.ANSI.reset()}")
    IO.puts("")

    port = Port.open({:spawn_executable, System.find_executable("npx")}, [
      :binary,
      :exit_status,
      :use_stdio,
      :stderr_to_stdout,
      args: ["wrangler", "dev"],
      cd: project_root
    ])

    stream_port(port)
  end

  defp apply_schema(project_root) do
    schema_path = Path.join(project_root, "schema.sql")
    wrangler_path = Path.join(project_root, "wrangler.jsonc")

    if File.exists?(schema_path) and File.exists?(wrangler_path) do
      case parse_database_name(wrangler_path) do
        {:ok, db_name} ->
          IO.puts("  #{IO.ANSI.faint()}Applying schema to local D1 (#{db_name})...#{IO.ANSI.reset()}")

          {output, status} =
            System.cmd("npx", ["wrangler", "d1", "execute", db_name, "--local", "--file=schema.sql"],
              cd: project_root,
              stderr_to_stdout: true
            )

          if status != 0 do
            IO.puts("  #{IO.ANSI.yellow()}Warning: schema apply returned status #{status}#{IO.ANSI.reset()}")
            IO.puts("  #{IO.ANSI.faint()}#{String.trim(output)}#{IO.ANSI.reset()}")
          end

        :error ->
          IO.puts("  #{IO.ANSI.yellow()}Warning: could not parse database_name from wrangler.jsonc#{IO.ANSI.reset()}")
      end
    end
  end

  defp parse_database_name(wrangler_path) do
    content = File.read!(wrangler_path)

    case Regex.run(~r/"database_name"\s*:\s*"([^"]+)"/, content) do
      [_, db_name] -> {:ok, db_name}
      _ -> :error
    end
  end

  defp stream_port(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        stream_port(port)

      {^port, {:exit_status, status}} ->
        if status != 0 do
          Mix.raise("wrangler dev exited with status #{status}")
        end
    end
  end
end
