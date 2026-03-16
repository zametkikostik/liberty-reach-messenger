-- Liberty Reach Messenger v0.6.0 "Immortal Love"
-- Cloudflare D1 Database Schema (Migration-safe)

-- Users table: Public keys only (no private data)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    public_key TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_seen INTEGER
);

-- Messages table: E2EE encrypted content
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    encrypted_text TEXT NOT NULL,
    nonce TEXT NOT NULL,
    signature TEXT,
    is_love_immutable INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    expires_at INTEGER,
    deleted_at INTEGER
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_love ON messages(is_love_immutable);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);

-- Schema version
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL
);

-- Insert schema version v2
INSERT OR REPLACE INTO schema_version (version, applied_at) 
VALUES (2, strftime('%s', 'now') * 1000);
