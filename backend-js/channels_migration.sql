-- 📢 BROADCAST CHANNELS MIGRATION
-- Liberty Reach Messenger v0.9.5
-- Add broadcast channels support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- CHANNELS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    avatar_cid TEXT, -- IPFS CID for channel avatar
    owner_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER,
    subscriber_count INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0, -- Verified channel badge
    is_public INTEGER DEFAULT 1, -- 1 = anyone can join
    invite_link TEXT,
    settings TEXT DEFAULT '{}', -- JSON settings
    FOREIGN KEY (owner_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- CHANNEL SUBSCRIBERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS channel_subscribers (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    subscribed_at INTEGER NOT NULL,
    is_muted INTEGER DEFAULT 0,
    is_admin INTEGER DEFAULT 0, -- Channel admin
    UNIQUE(channel_id, user_id),
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- CHANNEL POSTS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS channel_posts (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    author_id TEXT NOT NULL,
    content TEXT NOT NULL, -- Encrypted content
    media_cid TEXT, -- Optional media (IPFS)
    media_type TEXT, -- image, video, file
    nonce TEXT NOT NULL,
    views_count INTEGER DEFAULT 0,
    is_pinned INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    edited_at INTEGER,
    deleted_at INTEGER,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- CHANNEL POST VIEWS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS channel_post_views (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    viewed_at INTEGER NOT NULL,
    UNIQUE(post_id, user_id),
    FOREIGN KEY (post_id) REFERENCES channel_posts(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for user's channels
CREATE INDEX IF NOT EXISTS idx_channels_owner ON channels(owner_id);

-- Index for channel subscribers
CREATE INDEX IF NOT EXISTS idx_channel_subscribers_channel ON channel_subscribers(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_subscribers_user ON channel_subscribers(user_id);

-- Index for channel posts
CREATE INDEX IF NOT EXISTS idx_channel_posts_channel ON channel_posts(channel_id, created_at DESC);

-- Index for post views
CREATE INDEX IF NOT EXISTS idx_channel_post_views_post ON channel_post_views(post_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 13, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'channel%';
