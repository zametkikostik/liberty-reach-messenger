-- Cloudflare D1 Schema for Liberty Reach Messenger
-- "A Love Story" - User Storage

-- Users table: stores registered users with their Ed25519 public keys
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,              -- SHA-256 hash of public key (64 hex chars)
    public_key TEXT NOT NULL,         -- Base64 encoded Ed25519 public key (44 chars)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP  -- Registration timestamp
);

-- Index for faster lookups by creation date
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Insert initial schema version
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO schema_version (version) VALUES (1);
