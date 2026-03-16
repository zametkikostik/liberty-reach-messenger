# Cloudflare D1 Database Setup Guide
## "A Love Story" - Liberty Reach Backend

This guide covers setting up Cloudflare D1 for persistent user storage.

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

## 🔧 Wrangler Configuration

Location: `backend/wrangler.toml`

```toml
name = "a-love-story"
main = "build/index.js"
compatibility_date = "2024-01-01"

[build]
command = "cargo install -q worker-build && worker-build --release"

# D1 Database Binding
[[d1_databases]]
binding = "DB"
database_name = "liberty-db"
database_id = "YOUR_DATABASE_ID"

[vars]
ENVIRONMENT = "production"

[dev]
port = 8787
local_protocol = "http"
```

---

## 🚀 CLI Setup Commands

### Step 1: Create D1 Database

```bash
cd /home/kostik/Рабочий стол/папка для программирования/liberty-sovereign/backend

# Create the database in Cloudflare
npx wrangler d1 create liberty-db
```

**Expected Output:**
```
✅ Successfully created database 'liberty-db' in account YOUR_ACCOUNT
Database ID: abc123def456...
```

**Important:** Copy the `database_id` from the output!

---

### Step 2: Update wrangler.toml

Replace `YOUR_DATABASE_ID` with the actual ID from Step 1:

```bash
# Edit wrangler.toml and set:
database_id = "abc123def456..."  # Your actual database ID
```

---

### Step 3: Execute Schema (Local Development)

```bash
# Initialize local D1 database with schema
npx wrangler d1 execute liberty-db --local --file=schema.sql
```

**Expected Output:**
```
✅ Executed schema.sql on liberty-db (local)
```

---

### Step 4: Execute Schema (Production)

```bash
# Apply schema to production database
npx wrangler d1 execute liberty-db --remote --file=schema.sql
```

**Expected Output:**
```
✅ Executed schema.sql on liberty-db (remote)
```

---

### Step 5: Deploy Worker

```bash
# Deploy with D1 binding (use VPN if needed)
https_proxy=http://127.0.0.1:10809 http_proxy=http://127.0.0.1:10809 npx wrangler deploy
```

---

## 🧪 Testing & Verification

### Check Database Status

```bash
# Query user count
npx wrangler d1 execute liberty-db --remote --command="SELECT COUNT(*) FROM users;"
```

### Test Registration Endpoint

```bash
# Generate a test key and register
curl -X POST https://a-love-story.zametkikostik.workers.dev/register \
  -H "Content-Type: application/json" \
  -d '{"public_key": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}'

# Expected response with D1:
# {"user_id":"66687aad...","short_user_id":"66687aad...","success":true,"message":"User registered in database"}
```

### Check Health Endpoint

```bash
curl https://a-love-story.zametkikostik.workers.dev/health

# Expected response:
# {"status":"ok","service":"A Love Story","database":"connected"}
```

### Check DB Status Endpoint

```bash
curl https://a-love-story.zametkikostik.workers.dev/db/status

# Expected response:
# {"status":"connected","user_count":0}
```

---

## 📊 Useful D1 Commands

```bash
# List all databases
npx wrangler d1 list

# View database info
npx wrangler d1 info liberty-db

# Execute SQL query
npx wrangler d1 execute liberty-db --remote --command="SELECT * FROM users LIMIT 10;"

# Export database (backup)
npx wrangler d1 export liberty-db --output=backup.sql

# Import database
npx wrangler d1 execute liberty-db --remote --file=backup.sql
```

---

## 🔍 Troubleshooting

### Error: "D1 binding not available"

**Cause:** Database binding not configured in wrangler.toml

**Solution:**
1. Verify `[[d1_databases]]` section exists in wrangler.toml
2. Ensure `binding = "DB"` matches `env.d1("DB")` in Rust code
3. Redeploy: `npx wrangler deploy`

---

### Error: "Database does not exist"

**Cause:** Database not created or wrong database_id

**Solution:**
```bash
# Create database
npx wrangler d1 create liberty-db

# Update database_id in wrangler.toml
# Redeploy
npx wrangler deploy
```

---

### Error: "Table does not exist"

**Cause:** Schema not applied

**Solution:**
```bash
# Apply schema
npx wrangler d1 execute liberty-db --remote --file=schema.sql
```

---

### Error: "Constraint violation" on INSERT

**Cause:** User already exists (PRIMARY KEY collision)

**Solution:** This is expected behavior! The Rust code handles this by:
1. Checking if user exists before INSERT
2. Returning `success: true` with message "User already exists"

---

## 📁 File Structure

```
backend/
├── src/
│   └── lib.rs              # Rust code with D1 integration
├── schema.sql              # SQL schema for D1
├── wrangler.toml           # Wrangler config with D1 binding
└── Cargo.toml              # Rust dependencies
```

---

## 🔐 Security Notes

1. **Input Validation:** All public keys are validated with `ed25519-dalek` before storage
2. **Idempotent Registration:** Duplicate registrations return success without error
3. **SQL Injection Prevention:** Using parameterized queries with `?1`, `?2` placeholders
4. **Error Handling:** Database errors are logged but don't break registration flow

---

## 📈 Next Steps

1. **Add User Metadata:** Extend schema with `last_seen`, `device_info`
2. **Message Storage:** Create `messages` table for encrypted message relay
3. **Contact Discovery:** Add `contacts` table for user relationships
4. **Rate Limiting:** Use D1 + KV for request rate limiting per user

---

## 📚 Resources

- [Cloudflare D1 Documentation](https://developers.cloudflare.com/d1/)
- [Worker-rust D1 Examples](https://github.com/cloudflare/workers-rs/tree/main/examples/d1)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/commands/)
