# Contributing to Dark Phoenix (elixir-fullstack-worker)

## Getting Started

```bash
git clone --recurse-submodules https://github.com/Jaketdaniels/elixir-workers
cd elixir-fullstack-worker
make setup        # Install cmake, erlang, elixir, python3
make priv         # Build AtomVM WASM + stdlib
make dev          # Generate starter project and start dev server
```

Visit `http://localhost:8797`

## Project Layout

```
packages/elixir_workers/       # Hex package (the framework)
  lib/                         # Framework modules (Conn, Router, KV, D1, JSON, etc.)
  lib/mix/tasks/               # Mix tasks: new, build, dev, deploy, migrate
  priv/templates/              # Project templates (index.js, router.ex.eex, etc.)
  test/                        # Unit tests
_build/starter/                # Generated test project (via `make dev`)
scripts/                       # Build scripts
```

## Development Workflow

1. Make changes to framework code in `packages/elixir_workers/lib/`
2. Run tests: `cd packages/elixir_workers && mix test`
3. Check formatting: `mix format --check-formatted`
4. Check warnings: `mix compile --warnings-as-errors`
5. Test end-to-end: `make dev` from project root

## Testing

```bash
cd packages/elixir_workers
mix test                        # Run all tests
mix test test/elixir_workers/json_test.exs  # Run specific test file
```

Tests cover the pure Elixir framework modules (JSON, URL, HTML, Conn, Body, Middleware, KV, D1, Packer). The JS worker layer (index.js) requires integration testing with wrangler.

## Code Style

- Run `mix format` before committing
- All compiler warnings are treated as errors in CI
- Keep framework modules minimal -- they run on AtomVM WASM

## Template Changes

Templates in `priv/templates/` generate new projects via `mix elixir_workers.new`. After changing templates:

1. Delete the starter project: `rm -rf _build/starter`
2. Regenerate: `make dev`
3. Verify the generated project works at localhost:8797

## Database Migrations

Migrations live in `priv/templates/migrations/`. Each file is numbered `NNNN_name.sql`. The `_migrations` table tracks which have been applied.

```bash
mix elixir_workers.migrate           # Apply locally
mix elixir_workers.migrate --remote  # Apply to production
```

## Pull Requests

- Target the `main` branch
- Ensure CI passes (lint, compile, test)
- Keep PRs focused -- one feature or fix per PR

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 License.
