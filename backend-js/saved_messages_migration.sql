-- 💾 SAVED MESSAGES MIGRATION
-- Liberty Reach Messenger v0.8.2
-- Add saved/favorite messages support

-- ═══════════════════════════════════════════════════════════════════════════
-- SAVED MESSAGES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS saved_messages (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    saved_at INTEGER NOT NULL,
    tags TEXT DEFAULT '', -- Comma-separated tags
    UNIQUE(message_id, user_id),
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for quick lookup by user
CREATE INDEX IF NOT EXISTS idx_saved_messages_user ON saved_messages(user_id);

-- Index for searching by tags
CREATE INDEX IF NOT EXISTS idx_saved_messages_tags ON saved_messages(tags) 
WHERE tags != '';

-- Index for sorting by saved date
CREATE INDEX IF NOT EXISTS idx_saved_messages_saved_at ON saved_messages(saved_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 9, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name='saved_messages';
-- PRAGMA table_info(saved_messages);
