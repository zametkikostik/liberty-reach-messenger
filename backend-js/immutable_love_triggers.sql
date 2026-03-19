-- 🔐 IMMORTAL LOVE TRIGGERS
-- Liberty Reach Messenger v0.7.3
-- Cloudflare D1 Database Triggers for Vault Protection
--
-- These triggers protect messages containing "Love" tokens from deletion or modification.
-- The protection is enforced at the DATABASE LEVEL - even API admins cannot bypass.

-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER 1: prevent_love_delete
-- Blocks DELETE operations on immutable messages
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TRIGGER IF NOT EXISTS prevent_love_delete
BEFORE DELETE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: This record is eternal (is_love_immutable=1)');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER 2: prevent_love_update
-- Blocks UPDATE operations on immutable messages
-- Prevents changing encrypted_text, is_love_immutable flag, or any content
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TRIGGER IF NOT EXISTS prevent_love_update
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot modify eternal record (is_love_immutable=1)');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER 3: prevent_love_soft_delete
-- Blocks setting deleted_at on immutable messages (soft delete protection)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TRIGGER IF NOT EXISTS prevent_love_soft_delete
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1 AND NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Eternal messages cannot be soft-deleted');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES (for testing)
-- ═══════════════════════════════════════════════════════════════════════════

-- Check triggers exist:
-- SELECT name, tbl_name, sql FROM sqlite_master WHERE type='trigger' AND name LIKE 'prevent_love%';

-- Test immutable message (should fail):
-- INSERT INTO messages (id, sender_id, receiver_id, encrypted_text, nonce, is_love_immutable, created_at)
-- VALUES ('test-1', 'user-1', 'user-2', 'encrypted', 'nonce', 1, strftime('%s', 'now') * 1000);
-- DELETE FROM messages WHERE id = 'test-1'; -- Should raise error

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 3, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);
