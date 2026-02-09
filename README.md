# Dark Phoenix

Realtime social map platform built with Elixir on Cloudflare Workers. Live location sharing, nearby user discovery, messaging, and token economy — all running on AtomVM compiled to WebAssembly.

## Quickstart

**Prerequisites:** Elixir 1.17+ / Erlang/OTP 26+ and Node.js 18+.

```bash
mix archive.install hex elixir_workers

mix elixir_workers.new my_app
cd my_app
mix deps.get

# Set up D1 database
wrangler d1 create phoenix-db
wrangler d1 execute phoenix-db --local --file=schema.sql

# Start dev server
mix elixir_workers.dev
```

Open http://localhost:8797.

## Features

- **Live Map** — Leaflet + OpenStreetMap with realtime user markers, geolocation tracking
- **Auth** — Better Auth (email/password) running in the JS layer, sessions passed to Elixir
- **Messaging** — Direct messages between users, token-gated (1 token per message)
- **Profiles** — User profiles with display name, bio, avatar
- **Token Economy** — 50 tokens on signup, 20 daily free refill, purchasable
- **Admin Dashboard** — User stats, message counts, token economy overview
- **Dark Phoenix Aesthetic** — Near-black base, amber-to-crimson fire gradients, Outfit typography

## Architecture

```
HTTP Request
  → JS Worker (Better Auth for /api/auth/*, session extraction for all routes)
  → stdin (JSON with auth context)
  → AtomVM WASM (Elixir router, views, business logic)
  → stdout (JSON response)
  → HTTP Response
```

Three layers:
1. **JS Worker** — WASI runtime + Better Auth middleware + session extraction
2. **atomvm-wasi/** — C platform adapter compiled to WASM
3. **Elixir code** — router, views, assets, all business logic

Bindings:
- **D1** — Users (Better Auth), profiles, messages, tokens
- **KV** — Live locations with 5-minute TTL

## Routes

| Route | Description |
|-------|-------------|
| `GET /` | Landing page (Dark Phoenix aesthetic) |
| `GET /login` | Sign in |
| `GET /signup` | Create account |
| `GET /app` | Live map with nearby users |
| `GET /profile` | Edit your profile |
| `GET /messages` | Message inbox |
| `GET /messages/:id` | Conversation thread |
| `GET /tokens` | Token balance + purchase |
| `GET /admin` | Admin dashboard |
| `POST /api/auth/*` | Better Auth (handled in JS) |
| `POST /api/location` | Update location (KV, TTL=300s) |
| `GET /api/nearby` | Nearby users from KV |
| `POST /api/messages` | Send message (costs 1 token) |

## Deploy

```bash
npx wrangler login

# Create production resources
wrangler d1 create phoenix-db
wrangler kv namespace create LOCATIONS

# Update wrangler.jsonc with real IDs, then:
wrangler d1 execute phoenix-db --file=schema.sql
mix elixir_workers.deploy
```

## Development (contributing)

```bash
make setup    # Install tools, clone AtomVM
make dev      # Build WASM, compile stdlib, start dev server on :8797
```

## License

Apache-2.0

Built on [AtomVM](https://github.com/atomvm/AtomVM) (Apache-2.0 OR LGPL-2.1-or-later).
See [NOTICE](NOTICE) and [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for attribution.
