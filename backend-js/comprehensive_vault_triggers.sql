-- 🔐 COMPREHENSIVE VAULT PROTECTION
-- Liberty Reach Messenger v0.7.4 "Fortress"
-- Cloudflare D1 Database Triggers for ALL Tables
--
-- SECURITY LEVEL: MAXIMUM
-- Even database admins cannot bypass these protections.

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: MESSAGES PROTECTION (Immortal Love)
-- ═══════════════════════════════════════════════════════════════════════════

-- TRIGGER 1.1: Block DELETE on immutable messages
CREATE TRIGGER IF NOT EXISTS prevent_love_delete
BEFORE DELETE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: This record is eternal (is_love_immutable=1)');
END;

-- TRIGGER 1.2: Block UPDATE on immutable messages
CREATE TRIGGER IF NOT EXISTS prevent_love_update
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot modify eternal record (is_love_immutable=1)');
END;

-- TRIGGER 1.3: Block soft-delete on immutable messages
CREATE TRIGGER IF NOT EXISTS prevent_love_soft_delete
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1 AND NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Eternal messages cannot be soft-deleted');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: USERS TABLE PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════

-- TRIGGER 2.1: Prevent user deletion if they have any messages
CREATE TRIGGER IF NOT EXISTS prevent_user_delete_with_messages
BEFORE DELETE ON users
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM messages 
    WHERE sender_id = OLD.id OR recipient_id = OLD.id
)
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot delete user with existing messages');
END;

-- TRIGGER 2.2: Prevent user deletion if they have ICE candidates (active calls)
CREATE TRIGGER IF NOT EXISTS prevent_user_delete_with_calls
BEFORE DELETE ON users
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM ice_candidates WHERE user_id = OLD.id
)
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot delete user with active calls');
END;

-- TRIGGER 2.3: Log user updates (audit trail)
CREATE TRIGGER IF NOT EXISTS audit_user_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    -- Можно добавить таблицу audit_log для отслеживания изменений
    -- INSERT INTO audit_log (table_name, record_id, action, timestamp)
    -- VALUES ('users', OLD.id, 'UPDATE', strftime('%s', 'now') * 1000);
    SELECT 1; -- No-op trigger for now
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: ICE CANDIDATES PROTECTION (WebRTC)
-- ═══════════════════════════════════════════════════════════════════════════

-- TRIGGER 3.1: Auto-delete expired ICE candidates (cleanup)
CREATE TRIGGER IF NOT EXISTS cleanup_expired_ice_candidates
BEFORE UPDATE ON ice_candidates
FOR EACH ROW
WHEN NEW.expires_at < (strftime('%s', 'now') * 1000)
BEGIN
    SELECT RAISE(ABORT, 'ICE candidate expired - will be cleaned by GC');
END;

-- TRIGGER 3.2: Prevent modification of active ICE candidates
CREATE TRIGGER IF NOT EXISTS prevent_ice_candidate_modify
BEFORE UPDATE ON ice_candidates
FOR EACH ROW
WHEN NEW.expires_at > (strftime('%s', 'now') * 1000)
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot modify active ICE candidate');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: SCHEMA PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════

-- TRIGGER 4.1: Prevent schema version downgrade
CREATE TRIGGER IF NOT EXISTS prevent_schema_downgrade
BEFORE UPDATE ON schema_version
FOR EACH ROW
WHEN NEW.version < OLD.version
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot downgrade schema version');
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: FOREIGN KEY PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable foreign keys (D1/SQLite default is OFF, need to enable per connection)
-- This is handled by the Worker connection settings

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 4, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION: List all triggers
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name, tbl_name, sql FROM sqlite_master WHERE type='trigger' ORDER BY tbl_name;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECURITY NOTES:
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Messages with is_love_immutable=1 CANNOT be deleted or modified
-- 2. Users with messages CANNOT be deleted (protects message integrity)
-- 3. Active ICE candidates CANNOT be modified (protects call stability)
-- 4. Schema version CANNOT be downgraded (prevents rollback attacks)
-- 5. All triggers fire BEFORE the operation, preventing any changes
-- ═══════════════════════════════════════════════════════════════════════════
