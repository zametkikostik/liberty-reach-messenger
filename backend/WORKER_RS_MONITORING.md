# worker-rs D1 Monitoring

## Tracking Cloudflare worker-rs D1 Database Support

This document tracks the progress of D1 database support in the worker-rs (workers-rs) project.

---

## 🔍 Current Status

**As of:** 16 марта 2026

**worker-rs Version:** 0.7.x  
**D1 Support:** ❌ Not available in stable release

**Our Implementation:**
- Rust Worker (`backend/`): Optimized stateless version (no D1)
- JavaScript Worker (`backend-js/`): Full D1 integration ✅

---

## 📊 Why D1 is Not Available in worker-rs 0.7

The `worker` crate (workers-rs) version 0.7 does not expose the underlying JavaScript `Env` object in a way that allows Rust code to access D1 bindings via `wasm-bindgen`.

**Technical Details:**
- `Env` struct doesn't implement `AsRef<JsValue>`
- No `env.d1("DB")` method available
- D1 bindings are present in the Worker environment but inaccessible from Rust

---

## 🔔 Monitoring Sources

### 1. GitHub Issues

**Primary Issue:**
- https://github.com/cloudflare/workers-rs/issues/329 - "D1 Database support"

**Related Issues:**
- https://github.com/cloudflare/workers-rs/issues/440 - "Accessing bindings from Rust"
- https://github.com/cloudflare/workers-rs/discussions/385 - "D1 binding with wasm-bindgen"

**Action:** Subscribe to these issues for updates.

---

### 2. GitHub Releases

**Watch for releases mentioning:**
- "D1"
- "Database"
- "Binding"
- "wasm-bindgen"

**RSS Feed:** https://github.com/cloudflare/workers-rs/releases.atom

---

### 3. Discord / Community

**Cloudflare Developers Discord:**
- Channel: `#workers-rs`
- Ask about D1 roadmap

**Workers Discord:**
- Channel: `#d1`
- Community updates on Rust integration

---

### 4. Twitter / Social

**Follow:**
- @cloudflaredev (Twitter)
- https://blog.cloudflare.com/workers-rs/

---

## 📅 Check Schedule

| Task | Frequency | Next Check |
|------|-----------|------------|
| GitHub Issues | Weekly | 23 марта 2026 |
| GitHub Releases | Weekly | 23 марта 2026 |
| Discord Community | Bi-weekly | 30 марта 2026 |
| Cloudflare Blog | Monthly | 16 апреля 2026 |

---

## 🎯 Migration Plan (When D1 Support Arrives)

When worker-rs adds D1 support, update the Rust Worker:

### Step 1: Update Dependencies

```toml
# Cargo.toml
[dependencies]
worker = "0.8"  # or whatever version adds D1 support
```

### Step 2: Update wrangler.toml

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "liberty-db"
database_id = "7713033b-1f5c-4f2c-9123-b1c989869035"
```

### Step 3: Update Rust Code

```rust
// src/lib.rs
#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let db = env.d1("DB")?;
    
    // Use D1
    db.prepare("INSERT INTO users ...").run().await?;
    
    // ...
}
```

### Step 4: Test & Deploy

```bash
cd backend
https_proxy=http://127.0.0.1:10809 http_proxy=http://127.0.0.1:10809 npx wrangler deploy
```

---

## 📝 Current Workarounds

Until native D1 support is available:

1. **Use JavaScript Worker** (`backend-js/`) for D1 operations ✅
2. **Keep Rust Worker** for high-performance crypto operations
3. **Hybrid approach:** Rust WASM module called from JavaScript Worker

---

## 📧 Notification Setup

### GitHub Notifications

```bash
# Watch repository
gh repo watch cloudflare/workers-rs

# Get notified of new issues
gh issue list --repo cloudflare/workers-rs --state open --label "enhancement"
```

### Email Alerts

Set up Google Alerts for:
- "workers-rs D1"
- "cloudflare workers rust database"
- "workers-rs release"

---

## 📊 Comparison Matrix

| Feature | Rust Worker 0.7 | JavaScript Worker |
|---------|-----------------|-------------------|
| **Ed25519 Crypto** | ✅ Native | ✅ via crypto.subtle |
| **D1 Database** | ❌ Not available | ✅ Full support |
| **Performance** | ⚡ Fast (WASM) | 🚀 Fast (V8) |
| **Bundle Size** | 📦 ~570 KB | 📦 ~7 KB |
| **Type Safety** | ✅ Compile-time | ⚠️ Runtime |
| **Cold Start** | 🐢 Slower | ⚡ Faster |

---

## 🎁 Recommendation

**Current Best Practice:**
- Use **JavaScript Worker** for production with D1 ✅
- Keep **Rust Worker** as backup for crypto-only operations
- Monitor worker-rs for D1 support updates 📡

**When D1 Support Arrives:**
- Migrate to Rust Worker for unified codebase
- Deprecate JavaScript Worker or keep as fallback

---

**Last Updated:** 16 марта 2026  
**Next Review:** 23 марта 2026
