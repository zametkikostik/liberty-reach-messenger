//! # A Love Story
//!
//! **Cloudflare Worker Backend для Liberty Reach Messenger**
//!
//! Ed25519 верификация подписей на Edge

use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use worker::*;

// ============================================================================
// Константы
// ============================================================================

const PUBLIC_KEY_SIZE: usize = 32;
const SIGNATURE_SIZE: usize = 64;

// ============================================================================
// Структуры данных
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterRequest {
    #[serde(with = "base64_array")]
    pub public_key: [u8; PUBLIC_KEY_SIZE],
    pub username_hash: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterResponse {
    pub user_id: String,
    pub short_user_id: String,
    pub success: bool,
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyResponse {
    pub valid: bool,
    pub user_id: Option<String>,
    pub error: Option<String>,
}

// ============================================================================
// Base64 сериализация
// ============================================================================

mod base64_array {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    
    pub fn serialize<S, const N: usize>(bytes: &[u8; N], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        base64::encode(bytes).serialize(serializer)
    }
    
    pub fn deserialize<'de, D, const N: usize>(deserializer: D) -> Result<[u8; N], D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        let bytes = base64::decode(&s).map_err(serde::de::Error::custom)?;
        
        if bytes.len() != N {
            return Err(serde::de::Error::invalid_length(
                bytes.len(),
                &format!("array of {} bytes", N),
            ));
        }
        
        let mut array = [0u8; N];
        array.copy_from_slice(&bytes);
        Ok(array)
    }
}

mod base64_vec {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    
    pub fn serialize<S>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        base64::encode(bytes).serialize(serializer)
    }
    
    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        base64::decode(&s).map_err(serde::de::Error::custom)
    }
}

// ============================================================================
// Криптографические операции
// ============================================================================

/// Генерация User ID из публичного ключа (SHA-256)
fn get_user_id(public_key: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(public_key);
    let result = hasher.finalize();
    hex::encode(result)
}

/// Короткий User ID для UI (16 символов)
fn get_short_user_id(public_key: &[u8]) -> String {
    let full_id = get_user_id(public_key);
    full_id[..16].to_string()
}

/// Верификация Ed25519 подписи
fn verify_signature(
    public_key: &[u8],
    payload: &[u8],
    signature: &[u8],
) -> Result<bool, anyhow::Error> {
    if public_key.len() != PUBLIC_KEY_SIZE {
        anyhow::bail!("Invalid public key size: expected {} bytes", PUBLIC_KEY_SIZE);
    }
    
    if signature.len() != SIGNATURE_SIZE {
        anyhow::bail!("Invalid signature size: expected {} bytes", SIGNATURE_SIZE);
    }
    
    if payload.is_empty() {
        anyhow::bail!("Payload cannot be empty");
    }
    
    let verifying_key = VerifyingKey::from_bytes(public_key)
        .map_err(|e| anyhow::anyhow!("Invalid public key: {}", e))?;
    
    let signature = Signature::from_slice(signature)
        .map_err(|e| anyhow::anyhow!("Invalid signature: {}", e))?;
    
    Ok(verifying_key.verify(payload, &signature).is_ok())
}

// ============================================================================
// Обработчики запросов
// ============================================================================

async fn handle_register(req: RegisterRequest) -> Result<RegisterResponse> {
    VerifyingKey::from_bytes(&req.public_key)
        .map_err(|e| anyhow::anyhow!("Invalid Ed25519 public key: {}", e))?;
    
    let user_id = get_user_id(&req.public_key);
    let short_user_id = get_short_user_id(&req.public_key);
    
    Ok(RegisterResponse {
        user_id,
        short_user_id,
        success: true,
    })
}

async fn handle_verify(req: VerifyRequest) -> Result<VerifyResponse> {
    match verify_signature(&req.public_key, &req.payload, &req.signature) {
        Ok(true) => Ok(VerifyResponse {
            valid: true,
            user_id: Some(get_user_id(&req.public_key)),
            error: None,
        }),
        Ok(false) => Ok(VerifyResponse {
            valid: false,
            user_id: None,
            error: Some("Signature verification failed".to_string()),
        }),
        Err(e) => Ok(VerifyResponse {
            valid: false,
            user_id: None,
            error: Some(e.to_string()),
        }),
    }
}

// ============================================================================
// Cloudflare Worker Entry Point
// ============================================================================

#[event(fetch)]
async fn main(req: Request, _env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();
    
    let router = Router::new();
    
    router
        // Health check
        .get("/health", |_, _| {
            Response::ok(serde_json::json!({
                "status": "healthy",
                "service": "A Love Story",
                "version": env!("CARGO_PKG_VERSION")
            }).to_string())
        })
        
        // POST /register
        .post("/register", |mut req, _| async move {
            let register_req: RegisterRequest = req.json().await
                .map_err(|e| Error::BadRequest(format!("Invalid JSON: {}", e)))?;
            
            match handle_register(register_req).await {
                Ok(response) => {
                    let json = serde_json::to_string(&response)
                        .map_err(|e| Error::InternalServerError(e.to_string()))?;
                    
                    Response::ok(json)
                        .map(|r| r.with_headers(headers_from_map(&map! {
                            "Content-Type" => "application/json",
                            "Access-Control-Allow-Origin" => "*",
                        })))
                }
                Err(e) => {
                    Response::ok(serde_json::json!({
                        "success": false,
                        "error": e.to_string()
                    }).to_string())
                    .map(|r| r.with_status(400))
                    .map(|r| r.with_headers(headers_from_map(&map! {
                        "Content-Type" => "application/json",
                        "Access-Control-Allow-Origin" => "*",
                    })))
                }
            }
        })
        
        // POST /verify
        .post("/verify", |mut req, _| async move {
            let verify_req: VerifyRequest = req.json().await
                .map_err(|e| Error::BadRequest(format!("Invalid JSON: {}", e)))?;
            
            match handle_verify(verify_req).await {
                Ok(response) => {
                    let json = serde_json::to_string(&response)
                        .map_err(|e| Error::InternalServerError(e.to_string()))?;
                    
                    Response::ok(json)
                        .map(|r| r.with_headers(headers_from_map(&map! {
                            "Content-Type" => "application/json",
                            "Access-Control-Allow-Origin" => "*",
                        })))
                }
                Err(e) => {
                    Response::ok(serde_json::json!({
                        "valid": false,
                        "error": e.to_string()
                    }).to_string())
                    .map(|r| r.with_status(500))
                    .map(|r| r.with_headers(headers_from_map(&map! {
                        "Content-Type" => "application/json",
                        "Access-Control-Allow-Origin" => "*",
                    })))
                }
            }
        })
        
        // CORS preflight
        .options("/*path", |_, _| {
            Response::empty()
                .map(|r| r.with_headers(headers_from_map(&map! {
                    "Access-Control-Allow-Origin" => "*",
                    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
                    "Access-Control-Allow-Headers" => "Content-Type",
                })))
        })
        
        // 404
        .or_else(|_, _| {
            Response::ok(serde_json::json!({
                "error": "Not found",
                "code": 404
            }).to_string())
            .map(|r| r.with_status(404))
        })
    
    router.run(req, _env).await
}

fn headers_from_map(map: &std::collections::HashMap<&str, &str>) -> Headers {
    let headers = Headers::new();
    for (key, value) in map {
        let _ = headers.set(*key, *value);
    }
    headers
}

// ============================================================================
// Тесты
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use wasm_bindgen_test::*;
    
    fn generate_test_keypair() -> ([u8; 32], [u8; 32]) {
        use ed25519_dalek::SigningKey;
        
        let mut secret = [0u8; 32];
        getrandom::getrandom(&mut secret).unwrap();
        
        let signing_key = SigningKey::from_bytes(&secret);
        let verifying_key = signing_key.verifying_key();
        
        (verifying_key.to_bytes(), signing_key.to_bytes())
    }
    
    #[wasm_bindgen_test]
    fn test_register_user() {
        let (public_key, _) = generate_test_keypair();
        
        let request = RegisterRequest {
            public_key,
            username_hash: Some("test".to_string()),
        };
        
        let response = handle_register(request).await.unwrap();
        
        assert!(response.success);
        assert_eq!(response.user_id.len(), 64);
        assert_eq!(response.short_user_id.len(), 16);
    }
    
    #[wasm_bindgen_test]
    fn test_verify_signature_valid() {
        use ed25519_dalek::Signer;
        
        let (public_key, secret_key) = generate_test_keypair();
        let payload = b"Test message";
        
        let signing_key = ed25519_dalek::SigningKey::from_bytes(&secret_key);
        let signature = signing_key.sign(payload);
        
        let request = VerifyRequest {
            public_key,
            payload: payload.to_vec(),
            signature: signature.to_bytes(),
        };
        
        let response = handle_verify(request).await.unwrap();
        
        assert!(response.valid);
        assert!(response.user_id.is_some());
    }
    
    #[wasm_bindgen_test]
    fn test_verify_signature_invalid() {
        let (public_key, _) = generate_test_keypair();
        let payload = b"Original";
        let tampered = b"Tampered";
        
        use ed25519_dalek::Signer;
        let (_, secret_key) = generate_test_keypair();
        let signing_key = ed25519_dalek::SigningKey::from_bytes(&secret_key);
        let signature = signing_key.sign(tampered);
        
        let request = VerifyRequest {
            public_key,
            payload: payload.to_vec(),
            signature: signature.to_bytes(),
        };
        
        let response = handle_verify(request).await.unwrap();
        
        assert!(!response.valid);
    }
}
