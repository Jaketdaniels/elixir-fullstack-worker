defmodule Mix.Tasks.ElixirWorkers.New do
  use Mix.Task

  @shortdoc "Create a new ElixirWorkers project"

  @moduledoc """
  Creates a new ElixirWorkers fullstack project (Dark Phoenix).

      $ mix elixir_workers.new my_app

  The project name must be a valid Elixir app name (lowercase, underscores).

  This generates:
  - `mix.exs` with `:elixir_workers` dependency
  - `lib/my_app.ex` with the app entry point
  - `lib/my_app/router.ex` with fullstack routes + API handlers
  - `lib/my_app/views.ex` with all page renderers
  - `lib/my_app/assets.ex` with client JS + CSS
  - `wrangler.jsonc` for Cloudflare Workers config (KV + D1)
  - `package.json` with wrangler + better-auth deps
  - `schema.sql` for D1 migration
  - `.gitignore`

  After generating, run:
      $ cd my_app
      $ mix deps.get
      $ wrangler d1 create phoenix-db
      $ mix elixir_workers.dev
  """

  @impl Mix.Task
  def run(args) do
    case args do
      [name | _] ->
        generate(name)

      [] ->
        Mix.raise("Usage: mix elixir_workers.new APP_NAME")
    end
  end

  defp generate(name) do
    unless name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise(
        "App name must be lowercase, start with a letter, and only contain letters, numbers, and underscores. Got: #{name}"
      )
    end

    app_module = Macro.camelize(name)
    app_name = String.replace(name, "_", "-")
    project_dir = Path.join(File.cwd!(), name)

    if File.dir?(project_dir) do
      Mix.raise("Directory #{name} already exists")
    end

    IO.puts("")
    IO.puts("  #{IO.ANSI.magenta()}#{IO.ANSI.bright()}Creating#{IO.ANSI.reset()}  #{name}")
    IO.puts("")

    # Create directories
    File.mkdir_p!(Path.join(project_dir, "lib/#{name}"))

    templates_dir = templates_path()

    # Render Elixir templates
    assigns = [app_name: name, app_module: app_module]

    render_template(templates_dir, "mix.exs.eex", Path.join(project_dir, "mix.exs"), assigns)

    render_template(
      templates_dir,
      "app.ex.eex",
      Path.join(project_dir, "lib/#{name}.ex"),
      assigns
    )

    render_template(
      templates_dir,
      "router.ex.eex",
      Path.join(project_dir, "lib/#{name}/router.ex"),
      assigns
    )

    render_template(
      templates_dir,
      "views.ex.eex",
      Path.join(project_dir, "lib/#{name}/views.ex"),
      assigns
    )

    render_template(
      templates_dir,
      "assets.ex.eex",
      Path.join(project_dir, "lib/#{name}/assets.ex"),
      assigns
    )

    # Render Workers config at project root
    worker_assigns = [app_name: app_name, port: 8797]

    render_template(
      templates_dir,
      "wrangler.jsonc.eex",
      Path.join(project_dir, "wrangler.jsonc"),
      worker_assigns
    )

    render_template(
      templates_dir,
      "package.json.eex",
      Path.join(project_dir, "package.json"),
      worker_assigns
    )

    # Copy schema.sql (not a template, just a static file)
    schema_src = Path.join(templates_dir, "schema.sql")
    schema_dst = Path.join(project_dir, "schema.sql")

    if File.exists?(schema_src) do
      File.cp!(schema_src, schema_dst)
      created("schema.sql")
    end

    # Copy migrations directory
    migrations_src = Path.join(templates_dir, "migrations")

    if File.dir?(migrations_src) do
      migrations_dst = Path.join(project_dir, "migrations")
      File.mkdir_p!(migrations_dst)

      migrations_src
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".sql"))
      |> Enum.sort()
      |> Enum.each(fn file ->
        File.cp!(Path.join(migrations_src, file), Path.join(migrations_dst, file))
        created("migrations/#{file}")
      end)
    end

    # Write .gitignore
    File.write!(Path.join(project_dir, ".gitignore"), gitignore_content())
    created(".gitignore")

    # Generate .dev.vars with a random Better Auth secret
    secret = generate_secret()
    File.write!(Path.join(project_dir, ".dev.vars"), "BETTER_AUTH_SECRET=#{secret}\n")
    created(".dev.vars")

    IO.puts("")
    IO.puts("  #{IO.ANSI.green()}#{IO.ANSI.bright()}Your project is ready!#{IO.ANSI.reset()}")
    IO.puts("")
    IO.puts("  #{IO.ANSI.faint()}Next steps:#{IO.ANSI.reset()}")
    IO.puts("")
    IO.puts("      cd #{name}")
    IO.puts("      mix deps.get")
    IO.puts("      wrangler d1 create phoenix-db")
    IO.puts("      mix elixir_workers.dev")
    IO.puts("")
    IO.puts("  #{IO.ANSI.faint()}Then visit http://localhost:8797#{IO.ANSI.reset()}")
    IO.puts("")
  end

  defp templates_path do
    case :code.priv_dir(:elixir_workers) do
      {:error, _} ->
        Path.join([__DIR__, "..", "..", "..", "..", "priv", "templates"])
        |> Path.expand()

      priv_dir ->
        Path.join(to_string(priv_dir), "templates")
    end
  end

  defp render_template(templates_dir, template, output_path, assigns) do
    tmpl_path = Path.join(templates_dir, template)
    content = EEx.eval_file(tmpl_path, assigns: assigns)
    File.write!(output_path, content)
    created(Path.relative_to_cwd(output_path))
  end

  defp created(path) do
    IO.puts("  #{IO.ANSI.green()}+#{IO.ANSI.reset()} #{path}")
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp gitignore_content do
    """
    /_build/
    /deps/
    /node_modules/
    *.ez
    .elixir_ls/
    .dev.vars
    .wrangler/
    .DS_Store
    """
  end
end
