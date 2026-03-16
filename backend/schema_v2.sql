-- Cloudflare D1 Schema for Liberty Reach Messenger v0.6.0
-- "A Love Story" - User & Message Storage with Immutable Love Protocol

-- Users table: stores registered users with their Ed25519 public keys
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,              -- SHA-256 hash of public key (64 hex chars)
    public_key TEXT NOT NULL,         -- Base64 encoded Ed25519 public key (44 chars)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP  -- Registration timestamp
);

-- Messages table: stores encrypted messages with Immutable Love Protocol
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,              -- Message ID (UUID or hash)
    sender_id TEXT NOT NULL,          -- Sender's user ID (FK to users.id)
    recipient_id TEXT NOT NULL,       -- Recipient's user ID
    encrypted_text TEXT NOT NULL,     -- Encrypted message content
    nonce TEXT NOT NULL,              -- Encryption nonce (Base64)
    is_love_immutable INTEGER DEFAULT 0,  -- 1 if message contains "Love", 0 otherwise
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    deleted_at DATETIME DEFAULT NULL, -- Soft delete timestamp
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (recipient_id) REFERENCES users(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_love ON messages(is_love_immutable);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert schema version (v2 = Immutable Love Protocol)
INSERT OR IGNORE INTO schema_version (version) VALUES (2);
