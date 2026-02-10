-- Dark Phoenix — D1 Schema (Enhanced)
-- Run: wrangler d1 execute phoenix-db --local --file=schema.sql

-- Better Auth tables

CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  emailVerified INTEGER NOT NULL DEFAULT 0,
  image TEXT,
  createdAt TEXT NOT NULL DEFAULT (datetime('now')),
  updatedAt TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS "session" (
  id TEXT PRIMARY KEY,
  expiresAt TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  createdAt TEXT NOT NULL DEFAULT (datetime('now')),
  updatedAt TEXT NOT NULL DEFAULT (datetime('now')),
  ipAddress TEXT,
  userAgent TEXT,
  userId TEXT NOT NULL REFERENCES "user"(id)
);

CREATE TABLE IF NOT EXISTS "account" (
  id TEXT PRIMARY KEY,
  accountId TEXT NOT NULL,
  providerId TEXT NOT NULL,
  userId TEXT NOT NULL REFERENCES "user"(id),
  accessToken TEXT,
  refreshToken TEXT,
  idToken TEXT,
  accessTokenExpiresAt TEXT,
  refreshTokenExpiresAt TEXT,
  scope TEXT,
  password TEXT,
  createdAt TEXT NOT NULL DEFAULT (datetime('now')),
  updatedAt TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS "verification" (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL,
  value TEXT NOT NULL,
  expiresAt TEXT NOT NULL,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now'))
);

-- App tables

CREATE TABLE IF NOT EXISTS profiles (
  user_id TEXT PRIMARY KEY REFERENCES user(id),
  display_name TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  avatar_url TEXT DEFAULT '',
  age INTEGER,
  looking_for TEXT DEFAULT '',
  body_type TEXT DEFAULT '',
  position TEXT DEFAULT '',
  tribe TEXT DEFAULT '',
  is_verified INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_id TEXT NOT NULL REFERENCES user(id),
  to_id TEXT NOT NULL REFERENCES user(id),
  content TEXT NOT NULL,
  media_url TEXT DEFAULT '',
  message_type TEXT DEFAULT 'text',
  read INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_messages_to ON messages(to_id, read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_from ON messages(from_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(to_id, from_id, read) WHERE read = 0;
CREATE INDEX IF NOT EXISTS idx_messages_cursor ON messages(from_id, to_id, id DESC);

CREATE TABLE IF NOT EXISTS tokens (
  user_id TEXT PRIMARY KEY REFERENCES user(id),
  balance INTEGER DEFAULT 50,
  lifetime_earned INTEGER DEFAULT 50,
  daily_free_remaining INTEGER DEFAULT 20,
  daily_reset_at TEXT DEFAULT (datetime('now'))
);

-- Token transaction ledger

CREATE TABLE IF NOT EXISTS token_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES user(id),
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  tier TEXT DEFAULT '',
  balance_after INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_token_txns_user ON token_transactions(user_id, created_at DESC);

-- Moderation tables

CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reporter_id TEXT NOT NULL REFERENCES user(id),
  reported_user_id TEXT NOT NULL REFERENCES user(id),
  reason TEXT NOT NULL,
  details TEXT DEFAULT '',
  status TEXT DEFAULT 'pending',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reports_reported ON reports(reported_user_id, status);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id, created_at DESC);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id TEXT NOT NULL REFERENCES user(id),
  blocked_id TEXT NOT NULL REFERENCES user(id),
  created_at TEXT DEFAULT (datetime('now')),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);

-- Typing indicators (transient — currently using KV, D1 table reserved for history/audit)

CREATE TABLE IF NOT EXISTS typing_indicators (
  user_id TEXT NOT NULL REFERENCES user(id),
  conversation_with TEXT NOT NULL REFERENCES user(id),
  updated_at TEXT DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, conversation_with)
);

-- Anti-spam tables

CREATE TABLE IF NOT EXISTS rate_limits (
  key TEXT PRIMARY KEY,
  count INTEGER DEFAULT 1,
  window_start TEXT DEFAULT (datetime('now')),
  expires_at TEXT DEFAULT (datetime('now', '+1 hour'))
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_expires ON rate_limits(expires_at);

CREATE TABLE IF NOT EXISTS spam_scores (
  user_id TEXT PRIMARY KEY REFERENCES user(id),
  score REAL DEFAULT 1.0,
  total_flags INTEGER DEFAULT 0,
  last_flagged_at TEXT,
  is_banned INTEGER DEFAULT 0,
  ban_expires_at TEXT,
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Profile photos (multi-photo gallery)

CREATE TABLE IF NOT EXISTS profile_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  url TEXT NOT NULL,
  position INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_profile_photos_user ON profile_photos(user_id, position);
