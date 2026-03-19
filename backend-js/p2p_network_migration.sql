-- 🌐 P2P NETWORK MIGRATION
-- Liberty Reach Messenger v0.9.8
-- Add P2P network support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- P2P PEERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS p2p_peers (
    id TEXT PRIMARY KEY,
    peer_id TEXT UNIQUE NOT NULL,
    public_key TEXT NOT NULL,
    multiaddr TEXT, -- e.g., /ip4/192.168.1.1/tcp/4000
    last_seen INTEGER NOT NULL,
    is_online INTEGER DEFAULT 0,
    connection_type TEXT DEFAULT 'unknown', -- tcp, quic, relay
    protocols TEXT DEFAULT '[]', -- JSON array of supported protocols
    metadata TEXT DEFAULT '{}', -- Additional metadata
    created_at INTEGER NOT NULL
);

-- ═══════════════════════════════════════════════════════════════════════════
-- P2P DISCOVERY LOG TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS p2p_discovery_log (
    id TEXT PRIMARY KEY,
    peer_id TEXT NOT NULL,
    discovery_method TEXT NOT NULL, -- mdns, dht, bootstrap
    timestamp INTEGER NOT NULL,
    success INTEGER DEFAULT 0,
    error_message TEXT,
    FOREIGN KEY (peer_id) REFERENCES p2p_peers(peer_id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- P2P MESSAGE ROUTING TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS p2p_message_routing (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    from_peer TEXT NOT NULL,
    to_peer TEXT NOT NULL,
    routed_via TEXT, -- peers it was routed through
    timestamp INTEGER NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, delivered, failed
    retries INTEGER DEFAULT 0,
    FOREIGN KEY (from_peer) REFERENCES p2p_peers(peer_id),
    FOREIGN KEY (to_peer) REFERENCES p2p_peers(peer_id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- DHT CACHE TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS dht_cache (
    id TEXT PRIMARY KEY,
    key_hash TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    provider_peer TEXT,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for online peers
CREATE INDEX IF NOT EXISTS idx_p2p_peers_online ON p2p_peers(is_online);

-- Index for peer discovery
CREATE INDEX IF NOT EXISTS idx_p2p_peers_last_seen ON p2p_peers(last_seen DESC);

-- Index for DHT cache
CREATE INDEX IF NOT EXISTS idx_dht_cache_expires ON dht_cache(expires_at);

-- Index for message routing
CREATE INDEX IF NOT EXISTS idx_p2p_message_routing_status ON p2p_message_routing(status);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 16, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'p2p%' OR name LIKE 'dht%';
