//! Liberty P2P - Global Rust libp2p Core
//! 
//! Features:
//! - Kademlia DHT for global peer discovery
//! - Relay Client for NAT traversal
//! - Gossipsub for messaging
//! - E2EE encryption

use aes_gcm::{
    aead::{Aead, KeyInit, Payload},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose, Engine as _};
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use flutter_rust_bridge::*;
use hkdf::Hkdf;
use libp2p::{
    gossipsub, kad, mdns, noise, relay,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux, PeerId, Swarm, SwarmBuilder, Multiaddr,
    quic, dns, dcutr, identify,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{collections::HashMap, error::Error, sync::Arc, time::Duration};
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;
use x25519_dalek::{EphemeralSecret, PublicKey, SharedSecret};

pub mod frb_generated;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// 🔐 Identity Keys
#[derive(Debug, Clone, Serialize, Deserialize)]
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

/// 🔑 Session Keys
#[derive(Clone)]
pub struct SessionKeys {
    pub shared_secret: SharedSecret,
    pub aes_key: [u8; 32],
}

/// 📡 Peer Info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub peer_id: String,
    pub address: String,
    pub status: String,
    pub protocols: Vec<String>,
}

/// 🏗️ P2P Node State
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct P2PNode {
    pub peer_id: String,
    pub is_running: bool,
    pub connected_peers: Vec<String>,
    pub listen_addresses: Vec<String>,
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
    pub status: String,
}

// ============================================================================
// LIBP2P BEHAVIOUR
// ============================================================================

#[derive(NetworkBehaviour)]
struct LibertyBehaviour {
    gossipsub: gossipsub::Behaviour,
    kademlia: kad::Behaviour<kad::MemoryStore>,
    mdns: mdns::tokio::Behaviour,
    relay_client: relay::client::Behaviour,
    dcutr: dcutr::Behaviour,
    identify: identify::Behaviour,
}

// ============================================================================
// P2P SERVICE
// ============================================================================

pub struct P2PService {
    swarm: Option<Swarm<LibertyBehaviour>>,
    identity: IdentityKeys,
    is_running: bool,
    connected_peers: Vec<String>,
    listen_addresses: Vec<String>,
}

impl P2PService {
    /// 🚀 Create new P2P service
    pub fn new() -> Result<Self, Box<dyn Error>> {
        // Generate identity
        let signing_key = SigningKey::from_bytes(&rand::random::<[u8; 32]>());
        let verifying_key = VerifyingKey::from(&signing_key);
        let e2ee_secret = EphemeralSecret::random();
        let e2ee_public = PublicKey::from(&e2ee_secret);
        
        // Create libp2p keypair
        let keypair = libp2p::identity::Keypair::ed25519_from_bytes(signing_key.to_bytes())?;
        let peer_id = PeerId::from(keypair.public());
        
        let identity = IdentityKeys {
            peer_id: peer_id.to_string(),
            ed25519_public: general_purpose::STANDARD.encode(verifying_key.to_bytes()),
            ed25519_secret: general_purpose::STANDARD.encode(signing_key.to_bytes()),
            x25519_public: general_purpose::STANDARD.encode(e2ee_public.as_bytes()),
            x25519_secret: general_purpose::STANDARD.encode(e2ee_secret.to_bytes()),
        };
        
        Ok(Self {
            swarm: None,
            identity,
            is_running: false,
            connected_peers: Vec::new(),
            listen_addresses: Vec::new(),
        })
    }
    
    /// ▶️ Start P2P node with bootstrap nodes
    pub async fn start_p2p_node(&mut self, bootstrap_nodes: Vec<String>) -> Result<P2PNode, Box<dyn Error>> {
        tracing::info!("Starting P2P node: {}", self.identity.peer_id);
        
        // Create local key
        let local_key = libp2p::identity::Keypair::generate_ed25519();
        
        // Build swarm
        let mut swarm = SwarmBuilder::with_existing_identity(local_key)
            .with_tokio()
            .with_tcp(
                tcp::Config::default().port_reuse(true).nodelay(true),
                noise::Config::new,
                yamux::Config::default,
            )?
            .with_quic()
            .with_dns()?
            .with_relay_client(noise::Config::new, yamux::Config::default)?
            .with_behaviour(|keypair, relay_behaviour| {
                // Gossipsub
                let gossipsub_config = gossipsub::ConfigBuilder::default()
                    .heartbeat_interval(Duration::from_secs(10))
                    .validation_mode(gossipsub::ValidationMode::Strict)
                    .build()?;
                let gossipsub = gossipsub::Behaviour::new(
                    gossipsub::MessageAuthenticity::Signed(keypair.clone()),
                    gossipsub_config,
                )?;
                
                // Kademlia DHT
                let mut kademlia_config = kad::Config::default();
                kademlia_config.set_protocol_names(vec![std::borrow::Cow::Borrowed("/liberty/kad/1.0.0")]);
                let kademlia = kad::Behaviour::new(
                    PeerId::from(keypair.public()),
                    kad::MemoryStore::new(PeerId::from(keypair.public())),
                    kademlia_config,
                );
                
                // mDNS
                let mdns = mdns::tokio::Behaviour::new(
                    mdns::Config::default(),
                    PeerId::from(keypair.public()),
                )?;
                
                // DCUtR (hole punching)
                let dcutr = dcutr::Behaviour::new(PeerId::from(keypair.public()));
                
                // Identify
                let identify_config = identify::Behaviour::new(
                    identify::Config::new("/liberty/1.0.0".to_string(), keypair.public())
                        .with_interval(Duration::from_secs(60)),
                );
                
                Ok(LibertyBehaviour {
                    gossipsub,
                    kademlia,
                    mdns,
                    relay_client: relay_behaviour,
                    dcutr,
                    identify: identify_config,
                })
            })?
            .with_swarm_config(|c| c.with_idle_connection_timeout(Duration::from_secs(60)))
            .build();
        
        // Listen on all interfaces
        swarm.listen_on("/ip4/0.0.0.0/tcp/0".parse()?)?;
        swarm.listen_on("/ip4/0.0.0.0/udp/0/quic-v1".parse()?)?;
        
        // Enable relay
        swarm.behaviour_mut().relay_client.autodial_relay_peers();
        
        // Bootstrap Kademlia
        for bootstrap_node in bootstrap_nodes {
            if let Ok(addr) = bootstrap_node.parse::<Multiaddr>() {
                if let Some(peer_id) = addr.iter().find_map(|p| {
                    if let libp2p::multiaddr::Protocol::P2p(peer_id) = p {
                        Some(peer_id)
                    } else {
                        None
                    }
                }) {
                    swarm.behaviour_mut().kademlia.add_address(&peer_id, addr);
                }
            }
        }
        
        // Bootstrap Kademlia
        let _ = swarm.behaviour_mut().kademlia.bootstrap();
        
        self.swarm = Some(swarm);
        self.is_running = true;
        
        Ok(P2PNode {
            peer_id: self.identity.peer_id.clone(),
            is_running: true,
            connected_peers: Vec::new(),
            listen_addresses: Vec::new(),
        })
    }
    
    /// 🔍 Discover peers via Kademlia DHT
    pub async fn discover_peers(&self) -> Result<Vec<PeerInfo>, Box<dyn Error>> {
        // TODO: Query Kademlia DHT
        Ok(vec![])
    }
    
    /// 📨 Send encrypted message via Gossipsub
    pub async fn send_message(
        &self,
        receiver_public_key: &str,
        content: &str,
    ) -> Result<ChatMessage, Box<dyn Error>> {
        // Derive E2EE session
        let session = self.derive_shared_secret(receiver_public_key)?;
        
        // Encrypt
        let (ciphertext, nonce) = self.encrypt(&session, content)?;
        
        // Sign
        let signature = self.sign(ciphertext.as_bytes())?;
        
        let message = ChatMessage {
            id: Uuid::new_v4().to_string(),
            chat_id: format!("chat_{}_{}", self.identity.peer_id, receiver_public_key),
            sender_id: self.identity.peer_id.clone(),
            receiver_id: receiver_public_key.to_string(),
            content: ciphertext,
            encrypted: true,
            timestamp: chrono::Utc::now().timestamp() as u64,
            status: "sent".to_string(),
        };
        
        // TODO: Publish via Gossipsub
        // swarm.behaviour_mut().gossipsub.publish(topic, message)
        
        Ok(message)
    }
    
    /// ⏹️ Stop node
    pub async fn stop(&mut self) -> Result<(), Box<dyn Error>> {
        self.is_running = false;
        self.swarm = None;
        Ok(())
    }
    
    // ========================================================================
    // E2EE FUNCTIONS
    // ========================================================================
    
    fn sign(&self, data: &[u8]) -> Result<String, Box<dyn Error>> {
        let signing_key = SigningKey::from_bytes(
            &general_purpose::STANDARD.decode(&self.identity.ed25519_secret)?
        );
        let signature = signing_key.sign(data);
        Ok(general_purpose::STANDARD.encode(signature.to_bytes()))
    }
    
    fn verify(&self, signature_b64: &str, data: &[u8]) -> Result<bool, Box<dyn Error>> {
        let signature_bytes = general_purpose::STANDARD.decode(signature_b64)?;
        let signature = Signature::from_slice(&signature_bytes)?;
        let verifying_key = VerifyingKey::from_bytes(
            &general_purpose::STANDARD.decode(&self.identity.ed25519_public)?
        )?;
        Ok(verifying_key.verify(data, &signature).is_ok())
    }
    
    fn derive_shared_secret(&self, other_public_b64: &str) -> Result<SessionKeys, Box<dyn Error>> {
        let other_public_bytes = general_purpose::STANDARD.decode(other_public_b64)?;
        let other_public = PublicKey::from(other_public_bytes.as_slice().try_into()?);
        let e2ee_secret = EphemeralSecret::from_bytes(
            &general_purpose::STANDARD.decode(&self.identity.x25519_secret)?
        );
        let shared_secret = e2ee_secret.diffie_hellman(&other_public);
        
        let hkdf = Hkdf::<Sha256>::new(None, shared_secret.as_bytes());
        let mut aes_key = [0u8; 32];
        hkdf.expand(b"liberty_e2ee_aes256", &mut aes_key)?;
        
        Ok(SessionKeys { shared_secret, aes_key })
    }
    
    fn encrypt(&self, session: &SessionKeys, plaintext: &str) -> Result<(String, String), Box<dyn Error>> {
        let cipher = Aes256Gcm::new_from_slice(&session.aes_key)?;
        let nonce = Aes256Gcm::generate_nonce(&mut rand::thread_rng());
        let ciphertext = cipher.encrypt(&nonce, plaintext.as_bytes())?;
        
        Ok((
            general_purpose::STANDARD.encode(&ciphertext),
            general_purpose::STANDARD.encode(nonce),
        ))
    }
    
    fn decrypt(&self, session: &SessionKeys, ciphertext_b64: &str, nonce_b64: &str) -> Result<String, Box<dyn Error>> {
        let cipher = Aes256Gcm::new_from_slice(&session.aes_key)?;
        let ciphertext = general_purpose::STANDARD.decode(ciphertext_b64)?;
        let nonce = Nonce::from_slice(&general_purpose::STANDARD.decode(nonce_b64)?);
        let plaintext = cipher.decrypt(nonce, ciphertext.as_slice())?;
        Ok(String::from_utf8(plaintext)?)
    }
}

// ============================================================================
// FLUTTER RUST BRIDGE API
// ============================================================================

/// 🚀 Create identity
#[flutter_rust_bridge::frsync]
pub async fn create_identity() -> Result<IdentityKeys, String> {
    let service = P2PService::new().map_err(|e| e.to_string())?;
    Ok(service.identity)
}

/// ▶️ Start P2P node
#[flutter_rust_bridge::frsync]
pub async fn start_p2p_node(bootstrap_nodes: Vec<String>) -> Result<P2PNode, String> {
    let mut service = P2PService::new().map_err(|e| e.to_string())?;
    service.start_p2p_node(bootstrap_nodes).await.map_err(|e| e.to_string())
}

/// 🔍 Discover peers
#[flutter_rust_bridge::frsync]
pub async fn discover_peers() -> Result<Vec<PeerInfo>, String> {
    let service = P2PService::new().map_err(|e| e.to_string())?;
    service.discover_peers().await.map_err(|e| e.to_string())
}

/// 📨 Send message
#[flutter_rust_bridge::frsync]
pub async fn send_message(
    receiver_public_key: String,
    content: String,
) -> Result<ChatMessage, String> {
    let service = P2PService::new().map_err(|e| e.to_string())?;
    service.send_message(&receiver_public_key, &content).await.map_err(|e| e.to_string())
}

/// 🔐 Encrypt
#[flutter_rust_bridge::frsync]
pub async fn encrypt_message(
    my_secret_b64: String,
    their_public_b64: String,
    plaintext: String,
) -> Result<(String, String), String> {
    let service = P2PService::new().map_err(|e| e.to_string())?;
    let session = service.derive_shared_secret(&their_public_b64).map_err(|e| e.to_string())?;
    service.encrypt(&session, &plaintext).map_err(|e| e.to_string())
}

/// 🔓 Decrypt
#[flutter_rust_bridge::frsync]
pub async fn decrypt_message(
    my_secret_b64: String,
    their_public_b64: String,
    ciphertext_b64: String,
    nonce_b64: String,
) -> Result<String, String> {
    let service = P2PService::new().map_err(|e| e.to_string())?;
    let session = service.derive_shared_secret(&their_public_b64).map_err(|e| e.to_string())?;
    service.decrypt(&session, &ciphertext_b64, &nonce_b64).map_err(|e| e.to_string())
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_identity_creation() {
        let service = P2PService::new().unwrap();
        assert!(!service.identity.peer_id.is_empty());
    }
    
    #[tokio::test]
    async fn test_e2ee_roundtrip() {
        let alice = P2PService::new().unwrap();
        let bob = P2PService::new().unwrap();
        
        let alice_session = alice.derive_shared_secret(&bob.identity.x25519_public).unwrap();
        let bob_session = bob.derive_shared_secret(&alice.identity.x25519_public).unwrap();
        
        let (ciphertext, nonce) = alice.encrypt(&alice_session, "Hello!").unwrap();
        let plaintext = bob.decrypt(&bob_session, &ciphertext, &nonce).unwrap();
        
        assert_eq!(plaintext, "Hello!");
    }
}
