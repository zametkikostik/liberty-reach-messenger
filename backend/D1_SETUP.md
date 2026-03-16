# Cloudflare D1 Database Setup Guide
## "A Love Story" - Liberty Reach Backend

**Status:** Database created ✅, Schema applied ✅, Worker integration pending.

---

## ✅ Database Created

**Database Name:** `liberty-db`  
**Database ID:** `7713033b-1f5c-4f2c-9123-b1c989869035`  
**Region:** EEUR (Eastern Europe)  
**Schema:** Applied successfully

---

## 📋 SQL Schema

Location: `backend/schema.sql`

```sql
-- Users table: stores registered users with their Ed25519 public keys
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,              -- SHA-256 hash of public key (64 hex chars)
    public_key TEXT NOT NULL,         -- Base64 encoded Ed25519 public key (44 chars)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO schema_version (version) VALUES (1);
```

---

## 🔧 Current Status

The D1 database is ready and schema is applied. However, the Worker code currently uses `worker = "0.7"` which has limited D1 support via the Rust API.

### What's Working Now:
- ✅ Database created in Cloudflare
- ✅ Schema applied (users table ready)
- ✅ Worker deployed without D1 integration
- ✅ Registration and verification endpoints functional

### What's Pending:
- ⏳ Full D1 integration in Rust Worker (requires wasm-bindgen JS interop)
- ⏳ Persistent user storage across Worker restarts

---

## 🚀 CLI Commands Reference

### Query Database

```bash
# Count users
npx wrangler d1 execute liberty-db --remote --command="SELECT COUNT(*) FROM users;"

# List all users
npx wrangler d1 execute liberty-db --remote --command="SELECT * FROM users LIMIT 10;"
```

### Export/Import

```bash
# Export schema and data
npx wrangler d1 export liberty-db --output=backup.sql

# Import from SQL file
npx wrangler d1 execute liberty-db --remote --file=schema.sql
```

### Database Info

```bash
# List all databases
npx wrangler d1 list

# Get database info
npx wrangler d1 info liberty-db
```

---

## 📊 Current Worker Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/register` | POST | Register user (stateless) |
| `/verify` | POST | Verify Ed25519 signature |

**Test:**
```bash
curl https://a-love-story.zametkikostik.workers.dev/health
# {"status":"ok","service":"A Love Story"}
```

---

## 📈 Future Integration Steps

When worker-rs adds full D1 support or when implementing via wasm-bindgen:

1. **Add D1 binding to wrangler.toml:**
   ```toml
   [[d1_databases]]
   binding = "DB"
   database_name = "liberty-db"
   database_id = "7713033b-1f5c-4f2c-9123-b1c989869035"
   ```

2. **Add WASM dependencies to Cargo.toml:**
   ```toml
   [dependencies]
   wasm-bindgen = "0.2"
   wasm-bindgen-futures = "0.4"
   js-sys = "0.3"
   ```

3. **Update src/lib.rs** to use D1 via JS interop

---

## 📚 Resources

- [Cloudflare D1 Documentation](https://developers.cloudflare.com/d1/)
- [worker-rs GitHub](https://github.com/cloudflare/workers-rs)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/commands/)
