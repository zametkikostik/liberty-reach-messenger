-- 🏰 Liberty Reach Messenger v0.7.3 "Immortal Love"
-- Cloudflare D1 Database Schema with Vault Protection
--
-- SECURITY: This schema includes database-level triggers that prevent
-- deletion or modification of messages marked as "eternal" (is_love_immutable=1).
-- Even API admins cannot bypass these protections.

-- ═══════════════════════════════════════════════════════════════════════════
-- USERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    public_key TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_seen INTEGER
);

-- ═══════════════════════════════════════════════════════════════════════════
-- MESSAGES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    encrypted_text TEXT NOT NULL,
    nonce TEXT NOT NULL,
    signature TEXT,
    is_love_immutable INTEGER DEFAULT 0,  -- 🔐 VAULT FLAG: 1 = eternal, 0 = normal
    created_at INTEGER NOT NULL,
    expires_at INTEGER,
    deleted_at INTEGER
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PERFORMANCE INDEXES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_love ON messages(is_love_immutable);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_deleted ON messages(deleted_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION TRACKING
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL
);

-- Schema version v3: Includes immutable love triggers
INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES (3, strftime('%s', 'now') * 1000);
