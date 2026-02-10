# D1 Database Scaling Strategy

## D1 Limits (as of 2025)

| Limit | Free | Workers Paid |
|-------|------|-------------|
| Max database size | 500 MB | 10 GB |
| Max databases | 50 | 50,000 |
| Rows read per query | 5 million | 5 million |
| Rows written per query | 100,000 | 100,000 |
| Max query size | 100 KB | 100 KB |
| Max bind parameters | 100 | 100 |

## Current Schema Analysis

### Tables by Growth Rate

| Table | Growth Pattern | Estimated Size/User |
|-------|---------------|-------------------|
| user | Linear (signups) | ~200 bytes |
| session | Churn (expire) | ~300 bytes active |
| account | Linear (1:1 with user) | ~400 bytes |
| profiles | Linear (1:1 with user) | ~500 bytes |
| messages | High growth | ~200 bytes/msg |
| tokens | Linear (1:1 with user) | ~100 bytes |
| reports | Low growth | ~300 bytes |
| blocks | Moderate growth | ~50 bytes |
| rate_limits | Churn (TTL) | temporary |
| spam_scores | Linear (1:1 with user) | ~100 bytes |

### Capacity Estimates (10 GB limit)

- ~50,000 users with profiles: ~35 MB
- ~5 million messages: ~1 GB
- Sessions/accounts overhead: ~50 MB
- Indexes: ~20% of data size

**Comfortable capacity: ~50K users, ~25M messages before hitting 10 GB.**

## Scaling Strategies

### Phase 1: Index Optimization (0-10K users)

Current indexes are well-designed. Monitor query performance via `wrangler d1 insights`.

### Phase 2: Data Lifecycle (10K-50K users)

1. **Session cleanup**: Purge expired sessions periodically
   ```sql
   DELETE FROM session WHERE datetime(expiresAt) < datetime('now');
   ```

2. **Rate limit cleanup**: Already has `expires_at`, add periodic cleanup
   ```sql
   DELETE FROM rate_limits WHERE datetime(expires_at) < datetime('now');
   ```

3. **Message archival**: Consider archiving messages older than 90 days to R2 as JSON blobs

### Phase 3: Database Sharding (50K+ users)

D1 supports up to 50,000 databases. Shard by user geography or user ID range:

1. **Geographic sharding**: Route users to region-specific D1 databases based on CF `request.cf.colo`
2. **Hash-based sharding**: `database_index = hash(user_id) % NUM_SHARDS`
3. **Messages-only shard**: Move the messages table to a separate D1 database since it grows fastest

### Shard Router Pattern

```javascript
// In index.js, select DB based on shard key
function getDatabase(env, userId) {
  const shardIndex = simpleHash(userId) % env.NUM_SHARDS;
  return env[`DB_SHARD_${shardIndex}`];
}
```

Each shard gets its own D1 binding in wrangler.jsonc:

```jsonc
"d1_databases": [
  { "binding": "DB_SHARD_0", "database_name": "phoenix-shard-0", "database_id": "..." },
  { "binding": "DB_SHARD_1", "database_name": "phoenix-shard-1", "database_id": "..." }
]
```

### Phase 4: Offload to KV/R2

- **KV**: Already used for locations. Consider KV for user preferences, feature flags, cached profile data
- **R2**: Store media uploads (avatars, chat images), message archives, analytics exports

## Migration Versioning

Migrations are tracked in the `_migrations` table:

```sql
CREATE TABLE _migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TEXT DEFAULT (datetime('now'))
);
```

Each migration file in `migrations/` is numbered sequentially (0001, 0002, etc.) and runs exactly once. The `mix elixir_workers.migrate` task handles this automatically.

## Backup Strategy

D1 supports Time Travel (point-in-time recovery):
- Restore to any point within the last 30 days (paid plan)
- Use `wrangler d1 time-travel` commands

For additional safety:
1. Export critical data before major migrations
2. Test migrations against staging D1 first
3. Keep migration files in version control (they serve as a schema changelog)
