# elixir-fullstack-worker (Dark Phoenix)

Fullstack social map platform on Cloudflare Workers via AtomVM + WebAssembly.

## Project structure

Extends elixir-workers with fullstack templates: auth, map, messaging, tokens, admin.

```
elixir-fullstack-worker/
├── packages/
│   └── elixir_workers/             # Hex package (framework)
│       ├── lib/                    # Framework modules (unchanged from elixir-workers)
│       │   ├── elixir_workers.ex
│       │   ├── elixir_workers/     # conn, router, kv, d1, json, html, etc.
│       │   └── mix/tasks/          # new, build, dev, deploy
│       └── priv/
│           ├── atomvm.wasm
│           ├── stdlib/
│           └── templates/
│               ├── index.js        # WASI runtime + Better Auth middleware
│               ├── router.ex.eex   # Fullstack routes + API handlers
│               ├── views.ex.eex    # All page renderers (Dark Phoenix aesthetic)
│               ├── assets.ex.eex   # Client JS (Leaflet, geolocation, polling) + CSS
│               ├── schema.sql      # D1 migration (profiles, messages, tokens)
│               ├── app.ex.eex      # Entry point (unchanged)
│               ├── mix.exs.eex     # Mix project (unchanged)
│               ├── wrangler.jsonc.eex  # CF config with KV + D1 bindings
│               └── package.json.eex    # wrangler + better-auth deps
├── atomvm-wasi/                    # C platform adapter
├── vendor/AtomVM/                  # VM source
├── _build/starter/                 # Generated from templates (make dev)
└── scripts/
```

## Generated project structure

```
my_app/
├── lib/
│   ├── my_app.ex           # use ElixirWorkers.App
│   └── my_app/
│       ├── router.ex       # Routes + API handlers
│       ├── views.ex        # HTML pages (landing, map, auth, messages, admin)
│       └── assets.ex       # Client JS + CSS
├── mix.exs
├── wrangler.jsonc           # KV + D1 bindings
├── package.json             # wrangler + better-auth
├── schema.sql               # D1 migration
└── .gitignore
```

## User workflow

```bash
mix elixir_workers.new my_app
cd my_app && mix deps.get
wrangler d1 create phoenix-db
wrangler d1 execute phoenix-db --local --file=schema.sql
mix elixir_workers.dev          # builds .avm + starts wrangler on :8797
```

## Architecture

Four-layer request flow:

```
HTTP → JS Worker (Better Auth for /api/auth/*, session extraction) → stdin (JSON + auth) → AtomVM WASM → Elixir → stdout (JSON) → HTTP
```

1. **index.js** — WASI runtime + Better Auth middleware. Auth routes handled entirely in JS. For all other routes, extracts session and injects `_state.auth` into the WASM stdin JSON.
2. **atomvm-wasi/** — C platform adapter with stdin/stdout NIFs
3. **Elixir router** — fullstack routes (HTML pages + JSON APIs)
4. **Two-pass bindings** — KV for locations (TTL=300s), D1 for users/profiles/messages/tokens

### Auth flow

- `/api/auth/*` → Better Auth handles directly in JS (never hits WASM)
- All other routes → JS extracts session via `auth.api.getSession()`, passes `{userId, email, name}` to Elixir via `_state.auth`
- Post-signup hook initializes profile and token rows in D1

### Token economy

- 50 tokens on signup, 20 daily free refill
- 1 token per message sent
- `POST /api/tokens/purchase` stub (adds tokens)

## Bindings

| Binding | Type | Purpose |
|---------|------|---------|
| `DB` | D1 | Users, profiles, messages, tokens |
| `LOCATIONS` | KV | Live locations (TTL=300s) |
| `BETTER_AUTH_SECRET` | var | Auth signing secret |
| `BETTER_AUTH_URL` | var | Base URL for auth |

## Key templates

| Template | Purpose |
|----------|---------|
| `index.js` | WASI runtime + Better Auth integration |
| `router.ex.eex` | 30+ routes: landing, auth pages, map, profile, messages, tokens, admin, all APIs |
| `views.ex.eex` | Layout + all page renderers with Dark Phoenix CSS inline |
| `assets.ex.eex` | Client JS (auth forms, Leaflet map, geolocation, nearby polling) + full CSS |
| `schema.sql` | D1 tables: profiles, messages, tokens (Better Auth manages user/session/account) |

## Development rules

- `priv/templates/index.js` is a complete WASI + Better Auth implementation — don't replace with a library
- The WASI shim includes `env` stubs for ETS/distribution — no-ops, don't remove
- Better Auth runs ONLY in the JS layer, never in WASM
- Auth state flows to Elixir via `_state.auth` in the enriched request JSON
- Dark Phoenix aesthetic: near-black (#0a0a0f), fire gradients (#f59e0b → #ef4444), Outfit font
- Port: dev server runs on **8797**
- Framework modules live in `packages/elixir_workers/lib/`
- No threading — `AVM_NO_SMP`, single-threaded only
- No zlib in WASI build — LitT chunks must be pre-decompressed by packer
