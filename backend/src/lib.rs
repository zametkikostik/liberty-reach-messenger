//! # A Love Story - Cloudflare Worker with D1 Database
//!
//! Persistent user storage using Cloudflare D1

use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use worker::*;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use js_sys::{Array, Reflect};
use std::rc::Rc;

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

// D1 JavaScript bindings
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_name = D1Database)]
    pub type D1Database;
    
    #[wasm_bindgen(method, catch, js_name = prepare)]
    pub fn prepare(this: &D1Database, query: &str) -> Result<D1PreparedStatement, JsValue>;
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_name = D1PreparedStatement)]
    pub type D1PreparedStatement;
    
    #[wasm_bindgen(method, catch)]
    pub fn bind(this: &D1PreparedStatement, values: &Array) -> Result<D1PreparedStatement, JsValue>;
    
    #[wasm_bindgen(method)]
    pub fn first(this: &D1PreparedStatement, col_name: Option<&str>) -> js_sys::Promise;
    
    #[wasm_bindgen(method)]
    pub fn run(this: &D1PreparedStatement) -> js_sys::Promise;
}

/// Register user in D1 database
async fn register_user_in_db(db: &D1Database, user_id: &str, public_key_base64: &str) -> Result<bool, String> {
    // Check if user already exists
    let stmt = db.prepare("SELECT id FROM users WHERE id = ?1")
        .map_err(|e| format!("DB prepare error: {:?}", e))?;
    
    let values = Array::new();
    values.push(&JsValue::from_str(user_id));
    
    let bound = stmt.bind(&values)
        .map_err(|e| format!("DB bind error: {:?}", e))?;
    
    let result: Result<JsValue, _> = JsFuture::from(bound.first(None))
        .await
        .map_err(|e| format!("DB fetch error: {:?}", e));
    
    let result = match result {
        Ok(r) => r,
        Err(e) => return Err(e),
    };
    
    if !result.is_null() && !result.is_undefined() {
        // User already exists
        return Ok(false);
    }

    // Insert new user
    let insert_stmt = db.prepare("INSERT INTO users (id, public_key) VALUES (?1, ?2)")
        .map_err(|e| format!("DB insert prepare error: {:?}", e))?;
    
    let insert_values = Array::new();
    insert_values.push(&JsValue::from_str(user_id));
    insert_values.push(&JsValue::from_str(public_key_base64));
    
    let insert_bound = insert_stmt.bind(&insert_values)
        .map_err(|e| format!("DB insert bind error: {:?}", e))?;
    
    JsFuture::from(insert_bound.run())
        .await
        .map_err(|e| format!("DB execution error: {:?}", e))?;

    Ok(true)
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    // Get D1 database binding from environment
    let db: Option<D1Database> = {
        use wasm_bindgen::JsCast;
        let js_env = env.as_ref();
        Reflect::get(js_env, &JsValue::from_str("DB"))
            .ok()
            .and_then(|v| v.dyn_into::<D1Database>().ok())
    };

    // Wrap in Rc for sharing
    let db_rc = db.map(Rc::new);

    Router::new()
        .get("/health", |_, _| Response::ok(
            serde_json::json!({
                "status": "ok",
                "service": "A Love Story",
                "database": "connected"
            }).to_string()
        ))
        .post_async("/register", move |mut req, _| {
            let db_clone = db_rc.clone();
            async move {
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
                        if let Some(database) = &db_clone {
                            match register_user_in_db(&**database, &user_id, &public_key_base64).await {
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
            }
        })
        .post_async("/verify", |mut req, _| async move {
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
        .options("/*path", |_, _| Response::empty())
        .run(req, env)
        .await
}
