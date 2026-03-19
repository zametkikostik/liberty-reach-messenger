-- 👍 EMOJI REACTIONS MIGRATION
-- Liberty Reach Messenger v0.9.3
-- Add emoji reactions support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- MESSAGE REACTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS message_reactions (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    reaction_type TEXT NOT NULL, -- emoji: ❤️, 👍, 😂, 😮, 😢, 😡
    created_at INTEGER NOT NULL,
    UNIQUE(message_id, user_id, reaction_type),
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Also for group messages
CREATE TABLE IF NOT EXISTS group_message_reactions (
    id TEXT PRIMARY KEY,
    group_message_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    reaction_type TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE(group_message_id, user_id, reaction_type),
    FOREIGN KEY (group_message_id) REFERENCES group_messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for quick lookup by message
CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON message_reactions(message_id);

-- Index for reactions by user
CREATE INDEX IF NOT EXISTS idx_message_reactions_user ON message_reactions(user_id);

-- Index for group message reactions
CREATE INDEX IF NOT EXISTS idx_group_message_reactions_message ON group_message_reactions(group_message_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 11, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%reactions%';
