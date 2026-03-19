-- 🤖 AI FUNCTIONS MIGRATION
-- Liberty Reach Messenger v0.9.7
-- Add AI features support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- AI CHAT HISTORY TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_chat_history (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    message TEXT NOT NULL,
    response TEXT NOT NULL,
    model TEXT DEFAULT 'qwen-2.5-coder-32b',
    created_at INTEGER NOT NULL,
    tokens_used INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- AI SUMMARIES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_summaries (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    summary TEXT NOT NULL,
    period_start INTEGER NOT NULL,
    period_end INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- AI TRANSLATIONS CACHE TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_translations_cache (
    id TEXT PRIMARY KEY,
    original_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_lang TEXT NOT NULL,
    target_lang TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    usage_count INTEGER DEFAULT 1,
    UNIQUE(original_text, source_lang, target_lang)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for AI chat history
CREATE INDEX IF NOT EXISTS idx_ai_chat_history_user ON ai_chat_history(user_id, created_at DESC);

-- Index for summaries
CREATE INDEX IF NOT EXISTS idx_ai_summaries_user ON ai_summaries(user_id, created_at DESC);

-- Index for translations cache
CREATE INDEX IF NOT EXISTS idx_ai_translations_cache_lookup ON ai_translations_cache(original_text, source_lang, target_lang);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 15, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'ai_%';
