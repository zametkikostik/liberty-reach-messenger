-- Liberty Reach Messenger v0.6.0 "Immortal Love"
-- Cloudflare D1 Database - ICE Candidates Table

-- ICE Candidates table: For WebRTC P2P connections
CREATE TABLE IF NOT EXISTS ice_candidates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    peer_id TEXT NOT NULL,
    candidate TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);

-- Indexes for ICE candidates
CREATE INDEX IF NOT EXISTS idx_ice_user ON ice_candidates(user_id);
CREATE INDEX IF NOT EXISTS idx_ice_expires ON ice_candidates(expires_at);

-- Update schema version
INSERT OR REPLACE INTO schema_version (version, applied_at) 
VALUES (3, strftime('%s', 'now') * 1000);
