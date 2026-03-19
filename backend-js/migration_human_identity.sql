-- 👤 HUMAN IDENTITY MIGRATION
-- Liberty Reach Messenger v0.7.5 "Human Touch"
-- Add user metadata: full_name, avatar_cid

-- ═══════════════════════════════════════════════════════════════════════════
-- ALTER USERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

-- Add full_name column (optional, user can set later)
ALTER TABLE users ADD COLUMN full_name TEXT;

-- Add avatar_cid column (IPFS CID for avatar image)
ALTER TABLE users ADD COLUMN avatar_cid TEXT;

-- Add bio column (optional short description)
ALTER TABLE users ADD COLUMN bio TEXT DEFAULT '';

-- Add phone_hash column (for contact discovery, optional)
ALTER TABLE users ADD COLUMN phone_hash TEXT;

-- Add email_hash column (for contact discovery, optional)
ALTER TABLE users ADD COLUMN email_hash TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for searching by full_name
CREATE INDEX IF NOT EXISTS idx_users_full_name ON users(full_name);

-- Index for avatar lookup
CREATE INDEX IF NOT EXISTS idx_users_avatar ON users(avatar_cid) WHERE avatar_cid IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 5, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- PRAGMA table_info(users);
-- Should show: id, public_key, created_at, last_seen, full_name, avatar_cid, bio, phone_hash, email_hash
