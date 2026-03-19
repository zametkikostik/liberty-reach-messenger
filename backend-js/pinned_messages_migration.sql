-- 📌 PINNED MESSAGES MIGRATION
-- Liberty Reach Messenger v0.8.1
-- Add pinned message support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- ALTER MESSAGES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

-- Add is_pinned column (default 0 = not pinned)
ALTER TABLE messages ADD COLUMN is_pinned INTEGER DEFAULT 0;

-- Add pinned_at column (timestamp when pinned)
ALTER TABLE messages ADD COLUMN pinned_at INTEGER;

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for quick lookup of pinned messages
CREATE INDEX IF NOT EXISTS idx_messages_pinned ON messages(
    sender_id, 
    recipient_id, 
    is_pinned
) WHERE is_pinned = 1 AND deleted_at IS NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 8, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- PRAGMA table_info(messages);
-- Should show: ..., is_pinned, pinned_at
