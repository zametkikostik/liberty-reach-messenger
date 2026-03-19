-- 👥 GROUP CHATS MIGRATION
-- Liberty Reach Messenger v0.9.0
-- Add group chat support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUPS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    avatar_cid TEXT, -- IPFS CID for group avatar
    owner_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER,
    member_count INTEGER DEFAULT 1,
    max_members INTEGER DEFAULT 1000,
    is_public INTEGER DEFAULT 0, -- 1 = anyone can join via link
    invite_link TEXT, -- Unique invite link
    settings TEXT DEFAULT '{}', -- JSON settings
    FOREIGN KEY (owner_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUP MEMBERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS group_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT DEFAULT 'member', -- owner, admin, moderator, member
    joined_at INTEGER NOT NULL,
    last_seen INTEGER,
    is_banned INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    UNIQUE(group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUP MESSAGES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS group_messages (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    encrypted_text TEXT NOT NULL,
    nonce TEXT NOT NULL,
    signature TEXT,
    message_type TEXT DEFAULT 'text', -- text, image, video, file
    is_pinned INTEGER DEFAULT 0,
    pinned_at INTEGER,
    is_deleted INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    edited_at INTEGER,
    deleted_at INTEGER,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUP INVITES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS group_invites (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    invite_code TEXT UNIQUE NOT NULL,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER,
    max_uses INTEGER,
    uses_count INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for user's groups
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);

-- Index for group's members
CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);

-- Index for group messages
CREATE INDEX IF NOT EXISTS idx_group_messages_group ON group_messages(group_id, created_at DESC);

-- Index for active invites
CREATE INDEX IF NOT EXISTS idx_group_invites_active ON group_invites(is_active, expires_at);

-- Index for group search
CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 10, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name IN ('groups', 'group_members', 'group_messages', 'group_invites');
