# 🔐 IMMORTAL LOVE VAULT
## Cloudflare D1 Database-Level Protection for Eternal Messages

**Version:** v0.7.3  
**Service:** Liberty Reach Messenger  
**Security Level:** DATABASE TRIGGER PROTECTION

---

## 📋 Overview

This implementation adds **database-level triggers** to Cloudflare D1 that prevent deletion or modification of messages containing "Love Tokens". The protection is enforced at the **SQL level** - even API administrators cannot bypass it.

### Key Features

- ✅ **3 Database Triggers** for comprehensive protection
- ✅ **Automatic detection** of love tokens via `is_love_token` flag
- ✅ **Graceful error handling** with specific JSON responses
- ✅ **Soft delete support** with immutable message protection

---

## 🗄️ SQL Schema

### File: `backend-js/immutable_love_triggers.sql`

```sql
-- TRIGGER 1: Block DELETE on immutable messages
CREATE TRIGGER prevent_love_delete
BEFORE DELETE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: This record is eternal');
END;

-- TRIGGER 2: Block UPDATE on immutable messages
CREATE TRIGGER prevent_love_update
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Cannot modify eternal record');
END;

-- TRIGGER 3: Block soft-delete on immutable messages
CREATE TRIGGER prevent_love_soft_delete
BEFORE UPDATE ON messages
FOR EACH ROW
WHEN OLD.is_love_immutable = 1 AND NEW.deleted_at IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, '🔒 VAULT PROTECTED: Eternal messages cannot be deleted');
END;
```

---

## 🚀 Deployment Steps

### Step 1: Apply SQL Triggers to D1

```bash
# Navigate to backend-js directory
cd backend-js

# Apply triggers to your D1 database
wrangler d1 execute liberty-reach-db --file=immutable_love_triggers.sql

# Verify triggers were created
wrangler d1 execute liberty-reach-db --command="SELECT name FROM sqlite_master WHERE type='trigger';"
```

### Step 2: Deploy Updated Worker

```bash
# Deploy the worker
wrangler deploy

# Or manually via Cloudflare Dashboard:
# 1. Go to Workers & Pages
# 2. Select your worker
# 3. Edit code and paste worker.js content
# 4. Save and Deploy
```

### Step 3: Test Vault Protection

```bash
# 1. Send a normal message
curl -X POST https://your-worker.workers.dev/send \
  -H "Content-Type: application/json" \
  -d '{
    "sender_id": "user-1",
    "receiver_id": "user-2",
    "encrypted_text": "encrypted-data",
    "nonce": "nonce-value"
  }'

# Response: { "status": "success", "is_immutable": false }

# 2. Send a LOVE TOKEN (immutable message)
curl -X POST https://your-worker.workers.dev/send \
  -H "Content-Type: application/json" \
  -d '{
    "sender_id": "user-1",
    "receiver_id": "user-2",
    "encrypted_text": "encrypted-love-message",
    "nonce": "nonce-value",
    "is_love_token": true
  }'

# Response: { "status": "success", "is_immutable": true, "vault_protected": true }

# 3. Try to delete the immutable message (should fail)
curl -X DELETE https://your-worker.workers.dev/messages/msg-123456-abcdef

# Response: {
#   "status": "error",
#   "message": "This record is eternal - cannot be deleted",
#   "vault_error": true
# }
```

---

## 🔌 API Reference

### POST /send

Send an encrypted message.

**Request Body:**
```json
{
  "sender_id": "user-1",
  "receiver_id": "user-2",
  "encrypted_text": "base64-encoded-ciphertext",
  "nonce": "base64-encoded-nonce",
  "signature": "optional-ed25519-signature",
  "is_love_token": false,  // 🔐 Set to true for immutable message
  "expires_at": null       // Optional expiration timestamp
}
```

**Success Response:**
```json
{
  "status": "success",
  "message_id": "msg-1234567890-abcdef",
  "is_immutable": false,
  "vault_protected": false,
  "created_at": 1234567890000
}
```

**Vault Error Response (403):**
```json
{
  "status": "error",
  "message": "This record is eternal",
  "vault_error": true,
  "details": "🔒 VAULT PROTECTED: This record is eternal (is_love_immutable=1)"
}
```

---

### DELETE /messages/:message_id

Delete a message (soft delete).

**Success Response:**
```json
{
  "status": "success",
  "message": "Message deleted",
  "message_id": "msg-1234567890-abcdef"
}
```

**Vault Error Response (403):**
```json
{
  "status": "error",
  "message": "This record is eternal - cannot be deleted",
  "vault_error": true
}
```

---

### GET /messages/:user_id

Get all messages for a user.

**Response:**
```json
{
  "status": "success",
  "count": 5,
  "messages": [
    {
      "id": "msg-123",
      "sender_id": "user-1",
      "receiver_id": "user-2",
      "encrypted_text": "...",
      "nonce": "...",
      "is_immutable": true,
      "vault_protected": true,
      "created_at": 1234567890000
    }
  ]
}
```

---

## 🛡️ Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT REQUEST                            │
│  DELETE /messages/msg-123 (Love Token)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 CLOUDFLARE WORKER                            │
│  - Receives DELETE request                                   │
│  - Executes: UPDATE messages SET deleted_at = ? WHERE ...    │
│  - Catches trigger error                                     │
│  - Returns: { "message": "This record is eternal" }          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              CLOUDFLARE D1 DATABASE                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  TRIGGER: prevent_love_soft_delete                   │   │
│  │  BEFORE UPDATE ON messages                           │   │
│  │  WHEN OLD.is_love_immutable = 1                      │   │
│  │  BEGIN SELECT RAISE(ABORT, 'VAULT PROTECTED') END;   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  RESULT: Transaction aborted, no changes applied             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Checklist

- [ ] **Deploy triggers** to D1 database
- [ ] **Send normal message** (is_love_token: false) → Success
- [ ] **Send love token** (is_love_token: true) → Success with vault_protected: true
- [ ] **Delete normal message** → Success
- [ ] **Delete love token** → Error 403 "This record is eternal"
- [ ] **Update normal message** → Success
- [ ] **Update love token** → Error 403 "This record is eternal"
- [ ] **Soft delete love token** → Error 403 "Eternal messages cannot be deleted"

---

## 📝 Migration Notes

### From v0.6.0 to v0.7.3

1. **New column:** `is_love_immutable` already exists in v0.6.0 ✅
2. **New triggers:** Run `immutable_love_triggers.sql` ✅
3. **Worker update:** Replace `worker.js` with new version ✅
4. **Schema version:** Updated to v3 ✅

---

## 🚨 Important Warnings

1. **NO UNDO:** Once a message is marked as `is_love_immutable = 1`, it **cannot** be deleted or modified.
2. **Database-level:** Triggers work at SQL level - API changes cannot bypass them.
3. **Test first:** Always test on a staging database before production.
4. **Backup:** Export your D1 data before applying triggers.

---

## 🔍 Verification Queries

```sql
-- Check triggers exist
SELECT name, tbl_name, sql 
FROM sqlite_master 
WHERE type='trigger' AND name LIKE 'prevent_love%';

-- Count immutable messages
SELECT COUNT(*) as eternal_count 
FROM messages 
WHERE is_love_immutable = 1;

-- List all immutable messages
SELECT id, sender_id, receiver_id, created_at 
FROM messages 
WHERE is_love_immutable = 1 
ORDER BY created_at DESC;

-- Check schema version
SELECT * FROM schema_version ORDER BY version DESC LIMIT 1;
```

---

## 📞 Support

**Issues:** GitHub Repository  
**Docs:** `/docs/VAULT_PROTECTION.md`  
**Version:** v0.7.3-immortal-love

---

*Built for freedom, encrypted for life. Some things are meant to be eternal.* 💖
