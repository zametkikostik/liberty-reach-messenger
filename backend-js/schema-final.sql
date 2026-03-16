-- Liberty Reach Messenger v0.6.0 "Immortal Love"
-- Cloudflare D1 Database Final Migration

-- Add missing columns
ALTER TABLE messages ADD COLUMN signature TEXT;
ALTER TABLE messages ADD COLUMN expires_at INTEGER;

-- Add last_seen to users if not exists
ALTER TABLE users ADD COLUMN last_seen INTEGER;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_messages_love ON messages(is_love_immutable);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);

-- Update schema version
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL
);

INSERT OR REPLACE INTO schema_version (version, applied_at) 
VALUES (2, strftime('%s', 'now') * 1000);
