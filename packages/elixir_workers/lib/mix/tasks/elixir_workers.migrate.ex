defmodule Mix.Tasks.ElixirWorkers.Migrate do
  use Mix.Task

  @shortdoc "Run D1 database migrations"

  @moduledoc """
  Applies pending D1 migrations to the local or remote database.

      $ mix elixir_workers.migrate           # local
      $ mix elixir_workers.migrate --remote  # production

  Migrations are SQL files in `migrations/` named `NNNN_name.sql`.
  Each migration is tracked in the `_migrations` table and only
  applied once.

  ## Options

    * `--remote` - run against the remote (deployed) D1 database
    * `--env` - wrangler environment (e.g. `staging`)
    * `--dir` - migrations directory (default: `migrations/`)

  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [remote: :boolean, env: :string, dir: :string],
        aliases: [r: :remote, e: :env, d: :dir]
      )

    remote? = Keyword.get(opts, :remote, false)
    env = Keyword.get(opts, :env, nil)
    migrations_dir = Keyword.get(opts, :dir, "migrations")

    project_root = File.cwd!()
    full_dir = Path.join(project_root, migrations_dir)

    unless File.dir?(full_dir) do
      Mix.raise("Migrations directory not found: #{full_dir}")
    end

    wrangler_path = Path.join(project_root, "wrangler.jsonc")

    db_name =
      case parse_database_name(wrangler_path) do
        {:ok, name} -> name
        :error -> Mix.raise("Could not parse database_name from wrangler.jsonc")
      end

    # Ensure _migrations table exists
    ensure_migrations_table(project_root, db_name, remote?, env)

    # Get applied migrations
    applied = get_applied_migrations(project_root, db_name, remote?, env)

    # Find pending migration files
    pending =
      full_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".sql"))
      |> Enum.sort()
      |> Enum.reject(fn file ->
        version = parse_version(file)
        version in applied
      end)

    if pending == [] do
      IO.puts("  #{IO.ANSI.green()}No pending migrations#{IO.ANSI.reset()}")
      :ok
    else
      IO.puts("")

      IO.puts(
        "  #{IO.ANSI.magenta()}#{IO.ANSI.bright()}Migrating#{IO.ANSI.reset()} #{length(pending)} pending migration(s)"
      )

      IO.puts("")

      Enum.each(pending, fn file ->
        version = parse_version(file)
        IO.puts("  #{IO.ANSI.cyan()}applying#{IO.ANSI.reset()} #{file}")

        run_migration(project_root, db_name, Path.join(migrations_dir, file), remote?, env)

        IO.puts("  #{IO.ANSI.green()}applied#{IO.ANSI.reset()}  #{file} (version #{version})")
      end)

      IO.puts("")
      IO.puts("  #{IO.ANSI.green()}#{IO.ANSI.bright()}Done#{IO.ANSI.reset()}")
    end
  end

  defp parse_version(filename) do
    case Regex.run(~r/^(\d+)/, filename) do
      [_, v] -> String.to_integer(v)
      _ -> 0
    end
  end

  defp parse_database_name(wrangler_path) do
    content = File.read!(wrangler_path)

    case Regex.run(~r/"database_name"\s*:\s*"([^"]+)"/, content) do
      [_, db_name] -> {:ok, db_name}
      _ -> :error
    end
  end

  defp wrangler_args(db_name, remote?, env) do
    base = ["wrangler", "d1", "execute", db_name]
    base = if remote?, do: base ++ ["--remote"], else: base ++ ["--local"]
    if env, do: base ++ ["--env=#{env}"], else: base
  end

  defp ensure_migrations_table(project_root, db_name, remote?, env) do
    sql =
      "CREATE TABLE IF NOT EXISTS _migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT DEFAULT (datetime('now')))"

    args = wrangler_args(db_name, remote?, env) ++ ["--command=#{sql}"]

    {_output, _status} =
      System.cmd("npx", args, cd: project_root, stderr_to_stdout: true)
  end

  defp get_applied_migrations(project_root, db_name, remote?, env) do
    sql = "SELECT version FROM _migrations ORDER BY version"
    args = wrangler_args(db_name, remote?, env) ++ ["--command=#{sql}", "--json"]

    {output, status} =
      System.cmd("npx", args, cd: project_root, stderr_to_stdout: true)

    if status == 0 do
      # Parse JSON output from wrangler -- look for array of objects
      # wrangler d1 execute --json returns results in various formats
      trimmed = String.trim(output)

      if String.starts_with?(trimmed, "[") do
        results = ElixirWorkers.JSON.decode(trimmed)

        results
        |> List.flatten()
        |> Enum.filter(&is_map/1)
        |> Enum.map(&Map.get(&1, "version", 0))
      else
        []
      end
    else
      []
    end
  rescue
    _ -> []
  end

  defp run_migration(project_root, db_name, file_path, remote?, env) do
    args = wrangler_args(db_name, remote?, env) ++ ["--file=#{file_path}"]

    {output, status} =
      System.cmd("npx", args, cd: project_root, stderr_to_stdout: true)

    if status != 0 do
      Mix.raise("Migration failed: #{file_path}\n#{output}")
    end
  end
end
