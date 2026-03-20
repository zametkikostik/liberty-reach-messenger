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
-- ABCEX ORDERS TABLE (Crypto Purchase)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS abcex_orders (
    id TEXT PRIMARY KEY,
    wallet_id TEXT NOT NULL,
    order_id TEXT UNIQUE NOT NULL,
    fiat_amount TEXT NOT NULL,
    fiat_currency TEXT NOT NULL, -- USD, EUR, RUB, etc.
    crypto_token TEXT NOT NULL, -- MATIC, USDC, USDT
    crypto_amount TEXT NOT NULL,
    commission REAL DEFAULT 0.025, -- 2.5% commission
    payment_method TEXT,
    status TEXT DEFAULT 'pending', -- pending, completed, cancelled, failed
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- BITGET ORDERS TABLE (Exchange Operations)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bitget_orders (
    id TEXT PRIMARY KEY,
    wallet_id TEXT NOT NULL,
    order_id TEXT UNIQUE NOT NULL,
    from_token TEXT NOT NULL,
    to_token TEXT NOT NULL,
    amount TEXT NOT NULL,
    executed_amount TEXT,
    order_type TEXT DEFAULT 'market', -- market, limit
    status TEXT DEFAULT 'pending', -- pending, filled, cancelled, failed
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- P2P ESCROW TABLE (Smart Contract)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS p2p_escrows (
    id TEXT PRIMARY KEY,
    escrow_id TEXT UNIQUE NOT NULL,
    wallet_id TEXT NOT NULL,
    seller_address TEXT NOT NULL,
    buyer_address TEXT NOT NULL,
    amount TEXT NOT NULL,
    token_symbol TEXT NOT NULL,
    description TEXT,
    fee REAL DEFAULT 0.005, -- 0.5% escrow fee
    status TEXT DEFAULT 'active', -- active, completed, refunded, disputed
    created_at INTEGER NOT NULL,
    released_at INTEGER,
    refunded_at INTEGER,
    dispute_reason TEXT,
    FOREIGN KEY (wallet_id) REFERENCES crypto_wallets(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEE SPLITS TABLE (FeeSplitter)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fee_splits (
    id TEXT PRIMARY KEY,
    split_id TEXT UNIQUE NOT NULL,
    transaction_id TEXT NOT NULL,
    total_fee REAL NOT NULL,
    platform_share REAL NOT NULL,
    platform_address TEXT NOT NULL,
    lp_share REAL DEFAULT 0.0,
    lp_address TEXT,
    referrer_share REAL DEFAULT 0.0,
    referrer_address TEXT,
    status TEXT DEFAULT 'pending', -- pending, distributed, failed
    created_at INTEGER NOT NULL,
    distributed_at INTEGER,
    FOREIGN KEY (transaction_id) REFERENCES transactions(tx_hash) ON DELETE CASCADE
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

-- Index for ABCEX orders
CREATE INDEX IF NOT EXISTS idx_abcex_orders_wallet ON abcex_orders(wallet_id);
CREATE INDEX IF NOT EXISTS idx_abcex_orders_status ON abcex_orders(status);

-- Index for Bitget orders
CREATE INDEX IF NOT EXISTS idx_bitget_orders_wallet ON bitget_orders(wallet_id);
CREATE INDEX IF NOT EXISTS idx_bitget_orders_status ON bitget_orders(status);

-- Index for P2P escrows
CREATE INDEX IF NOT EXISTS idx_p2p_escrows_wallet ON p2p_escrows(wallet_id);
CREATE INDEX IF NOT EXISTS idx_p2p_escrows_status ON p2p_escrows(status);
CREATE INDEX IF NOT EXISTS idx_p2p_escrows_escrow_id ON p2p_escrows(escrow_id);

-- Index for fee splits
CREATE INDEX IF NOT EXISTS idx_fee_splits_transaction ON fee_splits(transaction_id);
CREATE INDEX IF NOT EXISTS idx_fee_splits_platform ON fee_splits(platform_address);
CREATE INDEX IF NOT EXISTS idx_fee_splits_lp ON fee_splits(lp_address);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEMA VERSION UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE schema_version SET version = 15, applied_at = strftime('%s', 'now') * 1000
WHERE version = (SELECT MAX(version) FROM schema_version);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%wallet%' OR name LIKE '%token%' OR name LIKE '%transaction%' OR name LIKE '%swap%';
