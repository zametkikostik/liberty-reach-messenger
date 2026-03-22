//! Liberty P2P - Rust libp2p Core with E2EE
//! 
//! Architecture:
//! - Rust: Core logic (libp2p, E2EE, identity)
//! - Flutter: UI only, calls Rust via flutter_rust_bridge

use aes_gcm::{
    aead::{Aead, KeyInit, Payload},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose, Engine as _};
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use hkdf::Hkdf;
use libp2p::{
    gossipsub, kad, mdns, noise, swarm::SwarmEvent, tcp, yamux, PeerId, Swarm, SwarmBuilder,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{collections::HashMap, error::Error, sync::Arc, time::Duration};
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;
use x25519_dalek::{EphemeralSecret, PublicKey, SharedSecret};

pub mod frb_generated; // flutter_rust_bridge generated code

// ============================================================================
// IDENTITY & E2EE
// ============================================================================

/// 🔐 Identity Keys (Ed25519 for signing, X25519 for E2EE)
#[derive(Clone, Serialize, Deserialize)]
pub struct IdentityKeys {
    pub peer_id: String,
    pub ed25519_public: String,
    pub ed25519_secret: String,
    pub x25519_public: String,
    pub x25519_secret: String,
}

/// 📦 Encrypted Message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedMessage {
    pub id: String,
    pub from: String,
    pub to: String,
    pub ciphertext: String,
    pub nonce: String,
    pub timestamp: u64,
    pub signature: String,
}

/// 📝 Decrypted Message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecryptedMessage {
    pub id: String,
    pub from: String,
    pub to: String,
    pub content: String,
    pub timestamp: u64,
    pub verified: bool,
}

/// 🔑 Session Keys (E2EE)
#[derive(Clone)]
pub struct SessionKeys {
    pub shared_secret: SharedSecret,
    pub aes_key: [u8; 32],
}

// ============================================================================
// IDENTITY MANAGER
// ============================================================================

/// 🔐 Identity Manager - Creates and manages E2EE keys
pub struct IdentityManager {
    keys: IdentityKeys,
    signing_key: SigningKey,
    e2ee_secret: EphemeralSecret,
}

impl IdentityManager {
    /// 🚀 Create new identity
    pub fn new() -> Result<Self, Box<dyn Error>> {
        // Ed25519 for signing
        let signing_key = SigningKey::from_bytes(&rand::random::<[u8; 32]>());
        let verifying_key = VerifyingKey::from(&signing_key);
        
        // X25519 for E2EE
        let e2ee_secret = EphemeralSecret::random();
        let e2ee_public = PublicKey::from(&e2ee_secret);
        
        // Generate Peer ID from public key
        let keypair = libp2p::identity::Keypair::ed25519_from_bytes(signing_key.to_bytes())?;
        let peer_id = PeerId::from(keypair.public());
        
        Ok(Self {
            keys: IdentityKeys {
                peer_id: peer_id.to_string(),
                ed25519_public: general_purpose::STANDARD.encode(verifying_key.to_bytes()),
                ed25519_secret: general_purpose::STANDARD.encode(signing_key.to_bytes()),
                x25519_public: general_purpose::STANDARD.encode(e2ee_public.as_bytes()),
                x25519_secret: general_purpose::STANDARD.encode(e2ee_secret.to_bytes()),
            },
            signing_key,
            e2ee_secret,
        })
    }
    
    /// 📤 Sign message with Ed25519
    pub fn sign(&self, data: &[u8]) -> Result<String, Box<dyn Error>> {
        let signature = self.signing_key.sign(data);
        Ok(general_purpose::STANDARD.encode(signature.to_bytes()))
    }
    
    /// ✅ Verify signature
    pub fn verify(&self, signature_b64: &str, data: &[u8]) -> Result<bool, Box<dyn Error>> {
        let signature_bytes = general_purpose::STANDARD.decode(signature_b64)?;
        let signature = Signature::from_slice(&signature_bytes)?;
        
        let verifying_key = VerifyingKey::from_bytes(
            &general_purpose::STANDARD.decode(&self.keys.ed25519_public)?
        )?;
        
        Ok(verifying_key.verify(data, &signature).is_ok())
    }
    
    /// 🔐 Derive E2EE shared secret (X25519 Diffie-Hellman)
    pub fn derive_shared_secret(&self, other_public_b64: &str) -> Result<SessionKeys, Box<dyn Error>> {
        let other_public_bytes = general_purpose::STANDARD.decode(other_public_b64)?;
        let other_public = PublicKey::from(other_public_bytes.as_slice().try_into()?);
        
        let shared_secret = self.e2ee_secret.diffie_hellman(&other_public);
        
        // HKDF to derive AES-256 key
        let hkdf = Hkdf::<Sha256>::new(None, shared_secret.as_bytes());
        let mut aes_key = [0u8; 32];
        hkdf.expand(b"liberty_e2ee_aes256", &mut aes_key)?;
        
        Ok(SessionKeys {
            shared_secret,
            aes_key,
        })
    }
    
    /// 🔒 Encrypt message with AES-256-GCM
    pub fn encrypt(&self, session: &SessionKeys, plaintext: &str) -> Result<(String, String), Box<dyn Error>> {
        let cipher = Aes256Gcm::new_from_slice(&session.aes_key)?;
        
        let nonce = Aes256Gcm::generate_nonce(&mut rand::thread_rng());
        let ciphertext = cipher.encrypt(&nonce, plaintext.as_bytes())?;
        
        Ok((
            general_purpose::STANDARD.encode(&ciphertext),
            general_purpose::STANDARD.encode(nonce),
        ))
    }
    
    /// 🔓 Decrypt message with AES-256-GCM
    pub fn decrypt(&self, session: &SessionKeys, ciphertext_b64: &str, nonce_b64: &str) -> Result<String, Box<dyn Error>> {
        let cipher = Aes256Gcm::new_from_slice(&session.aes_key)?;
        
        let ciphertext = general_purpose::STANDARD.decode(ciphertext_b64)?;
        let nonce = Nonce::from_slice(&general_purpose::STANDARD.decode(nonce_b64)?);
        
        let plaintext = cipher.decrypt(nonce, ciphertext.as_slice())?;
        Ok(String::from_utf8(plaintext)?)
    }
    
    /// 📋 Get identity keys (for export)
    pub fn get_keys(&self) -> IdentityKeys {
        self.keys.clone()
    }
}

// ============================================================================
// P2P NODE
// ============================================================================

/// 📡 P2P Node State
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct P2PNode {
    pub peer_id: String,
    pub is_running: bool,
    pub connected_peers: Vec<String>,
}

/// 🔍 Peer Info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub peer_id: String,
    pub address: String,
    pub status: String,
}

/// 📨 Chat Message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub chat_id: String,
    pub sender_id: String,
    pub receiver_id: String,
    pub content: String,
    pub encrypted: bool,
    pub timestamp: u64,
    pub status: String, // sent, delivered, read
}

/// 🏗️ P2P Service (libp2p swarm)
pub struct P2PService {
    identity: IdentityManager,
    is_running: bool,
    connected_peers: Vec<String>,
}

impl P2PService {
    /// 🚀 Create P2P service with identity
    pub fn new(identity: IdentityManager) -> Self {
        Self {
            identity,
            is_running: false,
            connected_peers: Vec::new(),
        }
    }
    
    /// ▶️ Start P2P node
    pub async fn start(&mut self) -> Result<(), Box<dyn Error>> {
        tracing::info!("Starting P2P node: {}", self.identity.keys.peer_id);
        
        // TODO: Initialize libp2p Swarm
        // - TCP transport
        // - Noise encryption
        // - Yamux multiplexing
        // - mDNS discovery
        // - Gossipsub for chats
        
        self.is_running = true;
        Ok(())
    }
    
    /// 🔍 Discover peers via mDNS
    pub async fn discover_peers(&self) -> Result<Vec<PeerInfo>, Box<dyn Error>> {
        tracing::info!("Discovering peers via mDNS...");
        
        // TODO: libp2p::mdns::tokio::Behaviour
        // For now, return empty (will be implemented with full libp2p)
        Ok(vec![])
    }
    
    /// 📨 Send encrypted message
    pub async fn send_message(
        &self,
        receiver_public_key: &str,
        content: &str,
    ) -> Result<ChatMessage, Box<dyn Error>> {
        tracing::info!("Sending message to {}", receiver_public_key);
        
        // Derive E2EE session
        let session = self.identity.derive_shared_secret(receiver_public_key)?;
        
        // Encrypt
        let (ciphertext, nonce) = self.identity.encrypt(&session, content)?;
        
        // Sign
        let signature = self.identity.sign(ciphertext.as_bytes())?;
        
        // Create message
        let message = ChatMessage {
            id: Uuid::new_v4().to_string(),
            chat_id: format!("chat_{}_{}", self.identity.keys.peer_id, receiver_public_key),
            sender_id: self.identity.keys.peer_id.clone(),
            receiver_id: receiver_public_key.to_string(),
            content: ciphertext,
            encrypted: true,
            timestamp: chrono::Utc::now().timestamp() as u64,
            status: "sent".to_string(),
        };
        
        // TODO: Send via Gossipsub
        // swarm.behaviour_mut().gossipsub.publish(topic, message)
        
        Ok(message)
    }
    
    /// 📥 Receive messages
    pub async fn receive_messages(&self) -> Result<Vec<ChatMessage>, Box<dyn Error>> {
        // TODO: Subscribe to Gossipsub topic
        Ok(vec![])
    }
    
    /// ⏹️ Stop node
    pub async fn stop(&mut self) -> Result<(), Box<dyn Error>> {
        tracing::info!("Stopping P2P node");
        self.is_running = false;
        self.connected_peers.clear();
        Ok(())
    }
}

// ============================================================================
// FLUTTER RUST BRIDGE API
// ============================================================================

/// 🚀 Create new identity (FFI)
#[flutter_rust_bridge::frsync]
pub async fn create_identity() -> Result<IdentityKeys, String> {
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    Ok(identity.get_keys())
}

/// 📡 Create P2P service (FFI)
#[flutter_rust_bridge::frsync]
pub async fn create_p2p_service(identity: IdentityKeys) -> Result<P2PNode, String> {
    // TODO: Reconstruct IdentityManager from keys
    // For now, create new
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    let mut service = P2PService::new(identity);
    
    service.start().await.map_err(|e| e.to_string())?;
    
    Ok(P2PNode {
        peer_id: identity.keys.peer_id,
        is_running: true,
        connected_peers: vec![],
    })
}

/// 🔍 Discover peers (FFI)
#[flutter_rust_bridge::frsync]
pub async fn discover_peers() -> Result<Vec<PeerInfo>, String> {
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    let service = P2PService::new(identity);
    
    service.discover_peers().await.map_err(|e| e.to_string())
}

/// 📨 Send encrypted message (FFI)
#[flutter_rust_bridge::frsync]
pub async fn send_encrypted_message(
    receiver_public_key: String,
    content: String,
) -> Result<ChatMessage, String> {
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    let service = P2PService::new(identity);
    
    service.send_message(&receiver_public_key, &content).await.map_err(|e| e.to_string())
}

/// 🔐 Encrypt message with session (FFI)
#[flutter_rust_bridge::frsync]
pub async fn encrypt_message(
    my_secret_b64: String,
    their_public_b64: String,
    plaintext: String,
) -> Result<(String, String), String> {
    // Reconstruct identity (simplified for demo)
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    let session = identity.derive_shared_secret(&their_public_b64).map_err(|e| e.to_string())?;
    
    identity.encrypt(&session, &plaintext).map_err(|e| e.to_string())
}

/// 🔓 Decrypt message with session (FFI)
#[flutter_rust_bridge::frsync]
pub async fn decrypt_message(
    my_secret_b64: String,
    their_public_b64: String,
    ciphertext_b64: String,
    nonce_b64: String,
) -> Result<String, String> {
    let identity = IdentityManager::new().map_err(|e| e.to_string())?;
    let session = identity.derive_shared_secret(&their_public_b64).map_err(|e| e.to_string())?;
    
    identity.decrypt(&session, &ciphertext_b64, &nonce_b64).map_err(|e| e.to_string())
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_identity_creation() {
        let identity = IdentityManager::new().unwrap();
        assert!(!identity.keys.peer_id.is_empty());
        assert!(!identity.keys.ed25519_public.is_empty());
        assert!(!identity.keys.x25519_public.is_empty());
    }
    
    #[tokio::test]
    async fn test_e2ee_roundtrip() {
        let alice = IdentityManager::new().unwrap();
        let bob = IdentityManager::new().unwrap();
        
        // Derive shared secrets
        let alice_session = alice.derive_shared_secret(&bob.keys.x25519_public).unwrap();
        let bob_session = bob.derive_shared_secret(&alice.keys.x25519_public).unwrap();
        
        // Encrypt
        let (ciphertext, nonce) = alice.encrypt(&alice_session, "Hello, Bob!").unwrap();
        
        // Decrypt
        let plaintext = bob.decrypt(&bob_session, &ciphertext, &nonce).unwrap();
        
        assert_eq!(plaintext, "Hello, Bob!");
    }
    
    #[tokio::test]
    async fn test_sign_verify() {
        let identity = IdentityManager::new().unwrap();
        let data = b"Test message";
        
        let signature = identity.sign(data).unwrap();
        let verified = identity.verify(&signature, data).unwrap();
        
        assert!(verified);
    }
}
