//! Key management - Fixed for ed25519-dalek 2.0

use zeroize::{Zeroize, ZeroizeOnDrop};

/// X25519 Public Key
pub type X25519PublicKey = [u8; 32];

/// X25519 Secret Key
pub type X25519SecretKey = [u8; 32];

/// Ed25519 Public Key
pub type Ed25519PublicKey = [u8; 32];

/// Ed25519 Secret Key (32 bytes seed + 32 bytes public = 64 bytes)
pub type Ed25519SecretKey = [u8; 64];

/// Ed25519 Signature
pub type Ed25519Signature = [u8; 64];

/// AES-256 Key
pub type Aes256Key = [u8; 32];

/// GCM Nonce
pub type GcmNonce = [u8; 12];

/// Shared Secret
pub type SharedSecret = [u8; 32];

/// Identity Key Pair
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct IdentityKeyPair {
    pub pq_public: [u8; 1184],
    pub pq_secret: [u8; 2400],
    pub ec_public: X25519PublicKey,
    pub ec_secret: X25519SecretKey,
    pub identity_public: Ed25519PublicKey,
    pub identity_secret: [u8; 32],  // Just the seed now
}

impl IdentityKeyPair {
    pub fn generate() -> Result<Self, CryptoError> {
        use rand::rngs::OsRng;
        
        let mut rng = OsRng;
        
        // Generate PQ keys (Kyber768) - returns Keypair struct
        let keypair = pqc_kyber::keypair(&mut rng);
        let pq_public = keypair.public;
        let pq_secret = keypair.secret;
        
        // Generate X25519 keys
        let ec_secret = x25519_dalek::StaticSecret::random_from_rng(&mut rng);
        let ec_public = x25519_dalek::PublicKey::from(&ec_secret);
        
        // Generate Ed25519 keys
        let identity_secret_key = ed25519_dalek::SigningKey::generate(&mut rng);
        let identity_public = identity_secret_key.verifying_key();
        let identity_secret = identity_secret_key.to_bytes();  // 32 bytes seed
        
        Ok(Self {
            pq_public,
            pq_secret,
            ec_public: ec_public.to_bytes(),
            ec_secret: ec_secret.to_bytes(),
            identity_public: identity_public.to_bytes(),
            identity_secret,
        })
    }
    
    pub fn sign(&self, data: &[u8]) -> Ed25519Signature {
        use ed25519_dalek::Signer;
        
        let signing_key = ed25519_dalek::SigningKey::from_bytes(&self.identity_secret);
        signing_key.sign(data).to_bytes()
    }
}

/// Ephemeral Keys
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct EphemeralKeys {
    pub ec_public: X25519PublicKey,
    pub ec_secret: X25519SecretKey,
}

impl EphemeralKeys {
    pub fn generate() -> Self {
        use rand::rngs::OsRng;
        
        let mut rng = OsRng;
        let ec_secret = x25519_dalek::StaticSecret::random_from_rng(&mut rng);
        let ec_public = x25519_dalek::PublicKey::from(&ec_secret);
        
        Self {
            ec_public: ec_public.to_bytes(),
            ec_secret: ec_secret.to_bytes(),
        }
    }
}

/// Crypto errors
#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("Key generation failed: {0}")]
    KeyGeneration(String),
    
    #[error("Key exchange failed: {0}")]
    KeyExchange(String),
    
    #[error("Encryption failed: {0}")]
    Encryption(String),
    
    #[error("Decryption failed: {0}")]
    Decryption(String),
}
