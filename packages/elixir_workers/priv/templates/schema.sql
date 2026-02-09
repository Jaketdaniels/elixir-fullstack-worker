-- Dark Phoenix — D1 Schema
-- Run: wrangler d1 execute phoenix-db --local --file=schema.sql

-- Better Auth manages these tables automatically:
--   user, session, account, verification

-- App tables

CREATE TABLE IF NOT EXISTS profiles (
  user_id TEXT PRIMARY KEY REFERENCES user(id),
  display_name TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  avatar_url TEXT DEFAULT '',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_id TEXT NOT NULL REFERENCES user(id),
  to_id TEXT NOT NULL REFERENCES user(id),
  content TEXT NOT NULL,
  read INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_messages_to ON messages(to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(from_id, to_id, created_at DESC);

CREATE TABLE IF NOT EXISTS tokens (
  user_id TEXT PRIMARY KEY REFERENCES user(id),
  balance INTEGER DEFAULT 50,
  lifetime_earned INTEGER DEFAULT 50,
  daily_free_remaining INTEGER DEFAULT 20,
  daily_reset_at TEXT DEFAULT (datetime('now'))
);
