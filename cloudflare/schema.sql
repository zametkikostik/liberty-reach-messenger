-- Liberty Reach Messenger - D1 Database Schema
-- Cloudflare D1 SQLite

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
    read INTEGER DEFAULT 0,
    FOREIGN KEY (from_user) REFERENCES users(id),
    FOREIGN KEY (to_user) REFERENCES users(id)
);

-- Chats table (for group chats in future)
CREATE TABLE IF NOT EXISTS chats (
    id TEXT PRIMARY KEY,
    name TEXT,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Chat participants
CREATE TABLE IF NOT EXISTS chat_participants (
    chat_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    PRIMARY KEY (chat_id, user_id),
    FOREIGN KEY (chat_id) REFERENCES chats(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_from_user ON messages(from_user);
CREATE INDEX IF NOT EXISTS idx_messages_to_user ON messages(to_user);
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- Insert demo users
INSERT OR IGNORE INTO users (id, username, public_key, created_at, last_seen, status) VALUES 
    ('user_demo1', 'Павел', 'pq_pub_demo1', 1708700000000, strftime('%s', 'now') * 1000, 'online'),
    ('user_demo2', 'Илон', 'pq_pub_demo2', 1708700000000, strftime('%s', 'now') * 1000, 'online'),
    ('user_demo3', 'LibertyNews', 'pq_pub_demo3', 1708700000000, strftime('%s', 'now') * 1000, 'online');

-- Insert demo messages
INSERT OR IGNORE INTO messages (id, chat_id, from_user, to_user, content, encrypted, created_at, read) VALUES 
    ('msg_demo1', 'user_demo1_user_demo2', 'user_demo1', 'user_demo2', 'Добро пожаловать в Liberty Reach! 🦅', 1, 1708700000000, 1),
    ('msg_demo2', 'user_demo1_user_demo2', 'user_demo2', 'user_demo1', 'Спасибо! Отличный мессенджер!', 1, 1708700100000, 1);
