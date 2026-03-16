-- Liberty Reach Messenger v0.6.0 "Immortal Love"
-- Cloudflare D1 Database Schema (Zero-Trust Architecture)
-- 
-- Security Model:
-- - ALL messages stored as ciphertext (E2EE)
-- - Cloudflare NEVER sees plaintext
-- - is_love_immutable flag set by CLIENT (trusted)
-- - Server-side guard prevents DELETE of love messages

-- Users table: Public keys only (no private data)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,              -- SHA-256 hash of public key (64 hex chars)
    public_key TEXT NOT NULL,         -- Base64 encoded Ed25519 public key (44 chars)
    created_at INTEGER NOT NULL,      -- Unix timestamp (milliseconds)
    last_seen INTEGER,                -- Last activity timestamp
    device_info TEXT                  -- Encrypted device metadata
);

-- Messages table: E2EE encrypted content
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,              -- Message UUID
    sender_id TEXT NOT NULL,          -- Sender's user ID (FK to users.id)
    receiver_id TEXT NOT NULL,        -- Receiver's user ID
    encrypted_text TEXT NOT NULL,     -- ⚠️ ALWAYS ciphertext (AES-256-GCM)
    nonce TEXT NOT NULL,              -- Encryption nonce (Base64, 12 bytes)
    signature TEXT,                   -- Ed25519 signature (for authenticity)
    is_love_immutable INTEGER DEFAULT 0,  -- 🛡 IMMUTABLE FLAG (1 = cannot delete)
    created_at INTEGER NOT NULL,      -- Unix timestamp
    expires_at INTEGER,               -- For disappearing messages (optional)
    deleted_at INTEGER,               -- Soft delete timestamp (NULL = active)
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (receiver_id) REFERENCES users(id)
);

-- ICE Candidates table: For WebRTC P2P connections
CREATE TABLE IF NOT EXISTS ice_candidates (
    id TEXT PRIMARY KEY,              -- Candidate UUID
    user_id TEXT NOT NULL,            -- Owner's user ID
    peer_id TEXT NOT NULL,            -- Target peer ID
    candidate TEXT NOT NULL,          -- ⚠️ Encrypted ICE candidate
    created_at INTEGER NOT NULL,      -- Unix timestamp
    expires_at INTEGER NOT NULL,      -- Auto-expire (24 hours)
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Indexes for performance (critical for mobile)
CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_love ON messages(is_love_immutable);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_expires ON messages(expires_at);
CREATE INDEX IF NOT EXISTS idx_ice_user ON ice_candidates(user_id);
CREATE INDEX IF NOT EXISTS idx_ice_expires ON ice_candidates(expires_at);

-- Schema version tracking (for migrations)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL,
    description TEXT
);

-- Insert schema version v2 (Immutable Love Protocol)
INSERT OR IGNORE INTO schema_version (version, applied_at, description) 
VALUES (2, strftime('%s', 'now') * 1000, 'Immutable Love Protocol + E2EE');

-- Cleanup query (run periodically via Cron Trigger)
-- DELETE FROM messages WHERE expires_at IS NOT NULL AND expires_at < strftime('%s', 'now') * 1000;
-- DELETE FROM ice_candidates WHERE expires_at < strftime('%s', 'now') * 1000;
