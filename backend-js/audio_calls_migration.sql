-- 📞 AUDIO CALLS MIGRATION
-- Liberty Reach Messenger v0.9.4
-- Add audio/video calls support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS calls (
    id TEXT PRIMARY KEY,
    caller_id TEXT NOT NULL,
    callee_id TEXT NOT NULL,
    call_type TEXT DEFAULT 'audio', -- audio, video
    status TEXT DEFAULT 'initiated', -- initiated, ringing, connected, missed, rejected, ended
    started_at INTEGER,
    ended_at INTEGER,
    duration INTEGER DEFAULT 0, -- in seconds
    FOREIGN KEY (caller_id) REFERENCES users(id),
    FOREIGN KEY (callee_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- CALL LOGS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS call_logs (
    id TEXT PRIMARY KEY,
    call_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- initiated, ringing, answered, ended, missed
    timestamp INTEGER NOT NULL,
    metadata TEXT, -- JSON metadata
    FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for user's calls
CREATE INDEX IF NOT EXISTS idx_calls_caller ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_callee ON calls(callee_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);

-- Index for call logs
CREATE INDEX IF NOT EXISTS idx_call_logs_call ON call_logs(call_id);
CREATE INDEX IF NOT EXISTS idx_call_logs_timestamp ON call_logs(timestamp DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 12, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name IN ('calls', 'call_logs');
