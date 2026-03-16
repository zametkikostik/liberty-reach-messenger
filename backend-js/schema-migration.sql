-- Liberty Reach Messenger v0.6.0 "Immortal Love"
-- Cloudflare D1 Database Migration

-- Users table: Add last_seen
ALTER TABLE users ADD COLUMN last_seen INTEGER;

-- Messages table: Add all columns
ALTER TABLE messages ADD COLUMN sender_id TEXT;
ALTER TABLE messages ADD COLUMN receiver_id TEXT;
ALTER TABLE messages ADD COLUMN encrypted_text TEXT;
ALTER TABLE messages ADD COLUMN nonce TEXT;
ALTER TABLE messages ADD COLUMN signature TEXT;
ALTER TABLE messages ADD COLUMN is_love_immutable INTEGER DEFAULT 0;
ALTER TABLE messages ADD COLUMN created_at INTEGER;
ALTER TABLE messages ADD COLUMN expires_at INTEGER;
ALTER TABLE messages ADD COLUMN deleted_at INTEGER;

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
