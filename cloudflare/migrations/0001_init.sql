-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    public_key TEXT,
    created_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    status TEXT DEFAULT 'offline' CHECK(status IN ('online', 'offline'))
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    from_user TEXT NOT NULL,
    to_user TEXT NOT NULL,
    content TEXT NOT NULL,
    encrypted INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    read INTEGER DEFAULT 0
);

-- Insert demo users
INSERT INTO users (id, username, public_key, created_at, last_seen, status) VALUES 
    ('user_pavel', 'Павел', 'pq_key_pavel', 1708700000000, 1708700000000, 'online'),
    ('user_elon', 'Илон', 'pq_key_elon', 1708700000000, 1708700000000, 'online'),
    ('user_news', 'LibertyNews', 'pq_key_news', 1708700000000, 1708700000000, 'online');
