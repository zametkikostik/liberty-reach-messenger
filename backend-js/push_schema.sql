-- 🔔 PUSH NOTIFICATIONS SCHEMA
-- Liberty Reach Messenger v0.7.9
-- Cloudflare D1 Database

-- ═══════════════════════════════════════════════════════════════════════════
-- PUSH TOKENS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS push_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    device_token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android', -- android, ios, web
    created_at INTEGER NOT NULL,
    last_seen INTEGER,
    is_active INTEGER DEFAULT 1,
    UNIQUE(user_id, device_token),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for looking up tokens by user
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);

-- Index for active tokens
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON push_tokens(is_active, last_seen);

-- Index for cleanup (old tokens)
CREATE INDEX IF NOT EXISTS idx_push_tokens_last_seen ON push_tokens(last_seen);

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION LOG (for analytics and debugging)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notification_log (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data TEXT, -- JSON string
    sent_at INTEGER NOT NULL,
    delivered INTEGER DEFAULT 0,
    read INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Index for notification history
CREATE INDEX IF NOT EXISTS idx_notification_log_user ON notification_log(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_log_sent ON notification_log(sent_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEANUP TRIGGER - Remove old inactive tokens (30 days)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TRIGGER IF NOT EXISTS cleanup_old_push_tokens
AFTER UPDATE ON push_tokens
FOR EACH ROW
WHEN NEW.last_seen < (strftime('%s', 'now') - 30*24*60*60) * 1000
BEGIN
    UPDATE push_tokens SET is_active = 0 WHERE id = NEW.id;
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 6, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name='push_tokens';
-- SELECT name FROM sqlite_master WHERE type='table' AND name='notification_log';
