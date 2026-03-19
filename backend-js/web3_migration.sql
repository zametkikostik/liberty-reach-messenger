-- 💰 WEB3 INTEGRATION MIGRATION
-- Liberty Reach Messenger v0.9.6
-- Add cryptocurrency wallet support to D1

-- ═══════════════════════════════════════════════════════════════════════════
-- CRYPTO WALLETS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS crypto_wallets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    address TEXT NOT NULL, -- Polygon wallet address
    created_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKEN BALANCES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS token_balances (
    id TEXT PRIMARY KEY,
    wallet_id TEXT NOT NULL,
    token_address TEXT, -- NULL for MATIC (native token)
    token_symbol TEXT NOT NULL, -- MATIC, USDC, USDT, etc.
    balance TEXT NOT NULL, -- Stored as string to preserve precision
    last_updated INTEGER NOT NULL,
    UNIQUE(wallet_id, token_address),
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TRANSACTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    wallet_id TEXT NOT NULL,
    tx_hash TEXT UNIQUE NOT NULL, -- Blockchain transaction hash
    type TEXT NOT NULL, -- send, receive, swap
    amount TEXT NOT NULL,
    token_symbol TEXT NOT NULL,
    from_address TEXT NOT NULL,
    to_address TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, confirmed, failed
    block_number INTEGER,
    timestamp INTEGER NOT NULL,
    gas_used TEXT,
    gas_price TEXT,
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- SWAPS TABLE (0x Protocol)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS swaps (
    id TEXT PRIMARY KEY,
    wallet_id TEXT NOT NULL,
    from_token TEXT NOT NULL,
    to_token TEXT NOT NULL,
    from_amount TEXT NOT NULL,
    to_amount TEXT NOT NULL,
    tx_hash TEXT,
    status TEXT DEFAULT 'pending',
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for wallet by user
CREATE INDEX IF NOT EXISTS idx_crypto_wallets_user ON crypto_wallets(user_id);

-- Index for token balances
CREATE INDEX IF NOT EXISTS idx_token_balances_wallet ON token_balances(wallet_id);

-- Index for transactions
CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_hash ON transactions(tx_hash);

-- Index for swaps
CREATE INDEX IF NOT EXISTS idx_swaps_wallet ON swaps(wallet_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 14, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%wallet%' OR name LIKE '%token%' OR name LIKE '%transaction%' OR name LIKE '%swap%';
