//! # A Love Story - Cloudflare Worker with D1 Database
//!
//! Persistent user storage using Cloudflare D1

use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use worker::*;

const PUBLIC_KEY_SIZE: usize = 32;
const SIGNATURE_SIZE: usize = 64;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterRequest {
    #[serde(with = "base64_array")]
    pub public_key: [u8; PUBLIC_KEY_SIZE],
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterResponse {
    pub user_id: String,
    pub short_user_id: String,
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyRequest {
    #[serde(with = "base64_array")]
    pub public_key: [u8; PUBLIC_KEY_SIZE],
    #[serde(with = "base64_vec")]
    pub payload: Vec<u8>,
    #[serde(with = "base64_array")]
    pub signature: [u8; SIGNATURE_SIZE],
}

mod base64_array {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    pub fn serialize<S, const N: usize>(bytes: &[u8; N], serializer: S) -> Result<S::Ok, S::Error>
    where S: Serializer {
        base64::encode(bytes).serialize(serializer)
    }
    pub fn deserialize<'de, D, const N: usize>(deserializer: D) -> Result<[u8; N], D::Error>
    where D: Deserializer<'de> {
        let s = String::deserialize(deserializer)?;
        let bytes = base64::decode(&s).map_err(serde::de::Error::custom)?;
        if bytes.len() != N {
            return Err(serde::de::Error::invalid_length(bytes.len(), &"32 bytes"));
        }
        let mut array = [0u8; N];
        array.copy_from_slice(&bytes);
        Ok(array)
    }
}

mod base64_vec {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    pub fn serialize<S>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where S: Serializer {
        base64::encode(bytes).serialize(serializer)
    }
    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where D: Deserializer<'de> {
        let s = String::deserialize(deserializer)?;
        base64::decode(&s).map_err(serde::de::Error::custom)
    }
}

fn get_user_id(public_key: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(public_key);
    hex::encode(hasher.finalize())
}

fn get_short_user_id(public_key: &[u8]) -> String {
    let id = get_user_id(public_key);
    id[..16].to_string()
}

fn verify_signature(public_key: &[u8; 32], payload: &[u8], signature: &[u8; 64]) -> Result<bool, String> {
    if payload.is_empty() {
        return Err("Empty payload".into());
    }
    let vk = VerifyingKey::from_bytes(public_key).map_err(|e| format!("Bad key: {}", e))?;
    let sig = Signature::from_slice(signature).map_err(|e| format!("Bad sig: {}", e))?;
    Ok(vk.verify(payload, &sig).is_ok())
}

/// Register user in D1 database
async fn register_user_in_db(db: &D1Database, user_id: &str, public_key_base64: &str) -> Result<bool, String> {
    // Check if user already exists
    let existing = db
        .prepare("SELECT id FROM users WHERE id = ?1")
        .bind(&[user_id.into()])
        .map_err(|e| format!("DB query error: {}", e))?
        .first::<serde_json::Value>(None)
        .await
        .map_err(|e| format!("DB fetch error: {}", e))?;

    if existing.is_some() {
        // User already exists - this is idempotent, return success
        return Ok(false);
    }

    // Insert new user
    db.prepare("INSERT INTO users (id, public_key) VALUES (?1, ?2)")
        .bind(&[user_id.into(), public_key_base64.into()])
        .map_err(|e| format!("DB insert error: {}", e))?
        .run()
        .await
        .map_err(|e| format!("DB execution error: {}", e))?;

    Ok(true)
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();
    
    // Get D1 database binding
    let db = match env.d1("DB") {
        Ok(database) => Some(database),
        Err(e) => {
            console_error!("D1 binding not available: {}", e);
            None
        }
    };

    Router::new()
        .get("/health", |_, _| Response::ok(
            serde_json::json!({
                "status": "ok",
                "service": "A Love Story",
                "database": if db.is_some() { "connected" } else { "not configured" }
            }).to_string()
        ))
        .post_async("/register", |mut req, ctx| async move {
            let reg: RegisterRequest = match req.json().await {
                Ok(r) => r,
                Err(e) => return Response::ok(
                    serde_json::json!({"success": false, "error": e.to_string()}).to_string()
                ).map(|r| r.with_status(400)),
            };
            
            // Validate public key
            match VerifyingKey::from_bytes(&reg.public_key) {
                Ok(_) => {
                    let user_id = get_user_id(&reg.public_key);
                    let short_user_id = get_short_user_id(&reg.public_key);
                    let public_key_base64 = base64::encode(&reg.public_key);
                    
                    // Try to store in D1 if available
                    let mut message = None;
                    if let Some(database) = &db {
                        match register_user_in_db(database, &user_id, &public_key_base64).await {
                            Ok(true) => message = Some("User registered in database".to_string()),
                            Ok(false) => message = Some("User already exists".to_string()),
                            Err(e) => {
                                console_error!("Database error: {}", e);
                                message = Some(format!("Registration succeeded but DB error: {}", e));
                            }
                        }
                    }
                    
                    let resp = RegisterResponse {
                        user_id,
                        short_user_id,
                        success: true,
                        message,
                    };
                    Response::ok(serde_json::to_string(&resp).unwrap())
                }
                Err(e) => Response::ok(
                    serde_json::json!({"success": false, "error": e.to_string()}).to_string()
                ).map(|r| r.with_status(400)),
            }
        })
        .post_async("/verify", |mut req, ctx| async move {
            let v: VerifyRequest = match req.json().await {
                Ok(r) => r,
                Err(e) => return Response::ok(
                    serde_json::json!({"valid": false, "error": e.to_string()}).to_string()
                ).map(|r| r.with_status(400)),
            };
            match verify_signature(&v.public_key, &v.payload, &v.signature) {
                Ok(true) => Response::ok(serde_json::json!({
                    "valid": true,
                    "user_id": get_user_id(&v.public_key)
                }).to_string()),
                Ok(false) => Response::ok(serde_json::json!({
                    "valid": false,
                    "error": "Bad signature"
                }).to_string()),
                Err(e) => Response::ok(serde_json::json!({
                    "valid": false,
                    "error": e
                }).to_string()),
            }
        })
        // D1 Admin endpoint - check database status
        .get("/db/status", |_, ctx| async move {
            match &db {
                Some(database) => {
                    // Count users in database
                    match database
                        .prepare("SELECT COUNT(*) as count FROM users")
                        .first::<serde_json::Value>(None)
                        .await
                    {
                        Ok(result) => {
                            let count = result.and_then(|v| v["count"].as_i64).unwrap_or(0);
                            Response::ok(serde_json::json!({
                                "status": "connected",
                                "user_count": count
                            }).to_string())
                        }
                        Err(e) => Response::ok(serde_json::json!({
                            "status": "error",
                            "error": e.to_string()
                        }).to_string())
                    }
                }
                None => Response::ok(serde_json::json!({
                    "status": "not configured"
                }).to_string())
            }
        })
        .options("/*path", |_, _| Response::empty())
        .run(req, env)
        .await
}
