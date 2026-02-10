# ElixirWorkers

Run Elixir on Cloudflare Workers via AtomVM compiled to WebAssembly.

## Quick Start

```bash
mix archive.install hex elixir_workers
mix elixir_workers.new my_app
cd my_app
mix deps.get
wrangler d1 create phoenix-db
wrangler d1 execute phoenix-db --local --file=schema.sql
mix elixir_workers.dev
```

Visit `http://localhost:8797`

## How It Works

ElixirWorkers compiles your Elixir code into a `.avm` archive that runs on AtomVM inside a Cloudflare Worker. The JS Worker runtime handles HTTP, auth (Better Auth), and binding fulfillment, while Elixir handles routing and business logic.

```
HTTP -> JS Worker -> stdin (JSON) -> AtomVM WASM -> Elixir -> stdout (JSON) -> HTTP
```

## Mix Tasks

| Task | Description |
|------|-------------|
| `mix elixir_workers.new APP` | Generate a new project |
| `mix elixir_workers.build` | Compile Elixir and pack .avm |
| `mix elixir_workers.dev` | Build + start local dev server |
| `mix elixir_workers.deploy` | Build + deploy to Cloudflare |
| `mix elixir_workers.migrate` | Run D1 database migrations |

## Bindings

- **D1** for SQL database (users, profiles, messages)
- **KV** for key-value storage (live locations with TTL)
- Two-pass architecture: Elixir declares what data it needs, JS fulfills it

## License

Apache-2.0
