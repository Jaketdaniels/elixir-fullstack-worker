# Deployment Guide

## Environments

| Environment | Worker Name | D1 Database | KV Namespace | URL |
|-------------|-------------|-------------|--------------|-----|
| Development | starter | phoenix-db (local) | LOCATIONS (local) | localhost:8797 |
| Staging | app-staging | phoenix-db-staging | staging-locations-kv | *.workers.dev |
| Production | app | phoenix-db | locations-kv | custom domain |

## Prerequisites

1. Cloudflare account with Workers paid plan
2. Wrangler CLI: `npm install -g wrangler`
3. Authenticate: `wrangler login`

## Initial Setup

### Create D1 Database

```bash
# Production
wrangler d1 create phoenix-db
# Note the database_id from output

# Staging
wrangler d1 create phoenix-db-staging
# Note the database_id from output
```

### Create KV Namespaces

```bash
# Production
wrangler kv namespace create LOCATIONS
# Note the namespace_id

# Staging
wrangler kv namespace create LOCATIONS --env staging
```

### Create R2 Bucket (for media uploads)

```bash
wrangler r2 bucket create app-media
```

### Set Secrets

```bash
# Generate a strong secret
openssl rand -base64 32

# Set for production
wrangler secret put BETTER_AUTH_SECRET
# Paste the secret when prompted

# Set for staging
wrangler secret put BETTER_AUTH_SECRET --env staging
```

### Update wrangler.jsonc

Replace placeholder IDs with the real values from the commands above:
- `locations-kv-id` -> actual KV namespace ID
- `phoenix-db-id` -> actual D1 database ID
- `staging-locations-kv-id` -> staging KV ID
- `staging-phoenix-db-id` -> staging D1 ID

## Deploy

### Manual Deploy

```bash
# Build
mix elixir_workers.build

# Deploy to staging
npx wrangler deploy --env staging

# Deploy to production
npx wrangler deploy
```

### Via Mix Task

```bash
mix elixir_workers.deploy
```

### Via CI/CD

Push to `main` deploys to staging automatically. Production deploys require manual trigger via GitHub Actions workflow dispatch.

## Database Migrations

### Local

```bash
mix elixir_workers.migrate
```

### Remote (Staging)

```bash
mix elixir_workers.migrate --remote --env staging
```

### Remote (Production)

```bash
mix elixir_workers.migrate --remote
```

### Manual Migration

```bash
wrangler d1 execute phoenix-db --file=migrations/0001_initial.sql
wrangler d1 execute phoenix-db --remote --file=migrations/0001_initial.sql
```

## Custom Domain

1. Add a custom domain in the Cloudflare dashboard under Workers > your worker > Settings > Domains & Routes
2. Update `BETTER_AUTH_URL` in wrangler.jsonc vars to match the custom domain
3. Redeploy

## Monitoring

- Cloudflare dashboard: Workers > your worker > Analytics
- Real-time logs: `wrangler tail`
- Staging logs: `wrangler tail --env staging`

## Rollback

Cloudflare Workers supports version rollback via the dashboard:
Workers > your worker > Deployments > select previous version > Rollback

## Environment Variables

| Variable | Where Set | Purpose |
|----------|-----------|---------|
| BETTER_AUTH_SECRET | `wrangler secret` | Auth token signing |
| BETTER_AUTH_URL | wrangler.jsonc vars | OAuth callback base URL |
| CF_API_TOKEN | GitHub Secrets | CI/CD deployment auth |
| CF_ACCOUNT_ID | GitHub Secrets | Cloudflare account identifier |
