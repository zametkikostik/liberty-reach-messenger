-- 📸 STORIES (24-Hour Messages) Schema
-- Liberty Reach Messenger v0.8.0
-- Cloudflare D1 Database

-- ═══════════════════════════════════════════════════════════════════════════
-- STORIES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS stories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    
    -- Content
    media_type TEXT DEFAULT 'image', -- image, video, text
    media_cid TEXT NOT NULL, -- IPFS CID for media
    media_nonce TEXT, -- Encryption nonce
    caption TEXT, -- Optional text caption
    
    -- Metadata
    width INTEGER DEFAULT 1080,
    height INTEGER DEFAULT 1920,
    duration INTEGER, -- For videos (seconds)
    
    -- Privacy
    is_public INTEGER DEFAULT 1, -- 1 = all contacts, 0 = close friends only
    view_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL, -- created_at + 24 hours
    deleted_at INTEGER,
    
    -- Foreign keys
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- STORY VIEWS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS story_views (
    id TEXT PRIMARY KEY,
    story_id TEXT NOT NULL,
    viewer_id TEXT NOT NULL,
    viewed_at INTEGER NOT NULL,
    
    UNIQUE(story_id, viewer_id),
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    FOREIGN KEY (viewer_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- STORY REPLIES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS story_replies (
    id TEXT PRIMARY KEY,
    story_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    reply_text TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Active stories (not expired, not deleted)
CREATE INDEX IF NOT EXISTS idx_stories_active ON stories(
    user_id, 
    expires_at, 
    deleted_at
) WHERE deleted_at IS NULL;

-- Stories by creation time
CREATE INDEX IF NOT EXISTS idx_stories_created ON stories(created_at DESC);

-- Cleanup (expired stories)
CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at) 
WHERE deleted_at IS NULL;

-- Story views by story
CREATE INDEX IF NOT EXISTS idx_story_views_story ON story_views(story_id);

-- Story views by viewer
CREATE INDEX IF NOT EXISTS idx_story_views_viewer ON story_views(viewer_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO-DELETE TRIGGER (24 hours)
-- ═══════════════════════════════════════════════════════════════════════════

-- Mark stories as deleted after 24 hours
CREATE TRIGGER IF NOT EXISTS auto_delete_expired_stories
AFTER UPDATE ON stories
FOR EACH ROW
WHEN NEW.expires_at < (strftime('%s', 'now') * 1000) AND OLD.deleted_at IS NULL
BEGIN
    UPDATE stories SET deleted_at = strftime('%s', 'now') * 1000 WHERE id = NEW.id;
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEANUP JOB (Remove old deleted stories)
-- ═══════════════════════════════════════════════════════════════════════════

-- This trigger physically deletes stories older than 7 days
CREATE TRIGGER IF NOT EXISTS cleanup_old_deleted_stories
AFTER UPDATE ON stories
FOR EACH ROW
WHEN NEW.deleted_at < (strftime('%s', 'now') - 7*24*60*60) * 1000
BEGIN
    DELETE FROM stories WHERE id = NEW.id;
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 7, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name='stories';
-- SELECT name FROM sqlite_master WHERE type='table' AND name='story_views';
-- SELECT name FROM sqlite_master WHERE type='table' AND name='story_replies';
