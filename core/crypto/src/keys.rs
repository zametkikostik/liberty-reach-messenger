//! Key management module
//! 
//! Provides key generation, storage, and exchange for Liberty Reach protocol

use zeroize::{Zeroize, ZeroizeOnDrop};
use serde::{Serialize, Deserialize};

/// Post-Quantum Public Key (CRYSTALS-Kyber 768)
pub type PqPublicKey = [u8; 1088];

/// Post-Quantum Secret Key (CRYSTALS-Kyber 768)
pub type PqSecretKey = [u8; 2400];

/// Kyber Ciphertext
pub type PqCiphertext = [u8; 1088];

/// X25519 Public Key
pub type X25519PublicKey = [u8; 32];

/// X25519 Secret Key
pub type X25519SecretKey = [u8; 32];

/// Ed25519 Public Key
pub type Ed25519PublicKey = [u8; 32];

/// Ed25519 Secret Key (64 bytes: seed + public)
pub type Ed25519SecretKey = [u8; 64];

/// Ed25519 Signature
pub type Ed25519Signature = [u8; 64];

/// AES-256 Key
pub type Aes256Key = [u8; 32];

/// HMAC Key
pub type HmacKey = [u8; 32];

/// GCM Nonce (96 bits)
pub type GcmNonce = [u8; 12];

/// Shared Secret from key exchange
pub type SharedSecret = [u8; 32];

/// Liberty Reach Identity Key Pair
/// 
/// Contains all long-term identity keys for a user
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct IdentityKeyPair {
    /// Post-Quantum keys (Kyber768)
    pub pq_public: PqPublicKey,
    pub pq_secret: PqSecretKey,
    
    /// ECDH keys (X25519)
    pub ec_public: X25519PublicKey,
    pub ec_secret: X25519SecretKey,
    
    /// Identity keys (Ed25519 for signing)
    pub identity_public: Ed25519PublicKey,
    pub identity_secret: Ed25519SecretKey,
}

/// PreKey Bundle for X3DH key exchange
#[derive(Clone, Serialize, Deserialize)]
pub struct PreKeyBundle {
    pub prekey_id: u32,
    pub pq_public: PqPublicKey,
    pub ec_public: X25519PublicKey,
    pub signature: Ed25519Signature,
}

/// One-Time Key for X3DH
#[derive(Clone, Serialize, Deserialize)]
pub struct OneTimeKey {
    pub key_id: u32,
    pub public: X25519PublicKey,
}

/// Ephemeral keys for a single session
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct EphemeralKeys {
    pub ec_public: X25519PublicKey,
    pub ec_secret: X25519SecretKey,
}

impl IdentityKeyPair {
    /// Generate a new identity key pair
    /// 
    /// # Security
    /// Uses cryptographically secure random number generator
    pub fn generate() -> Result<Self, CryptoError> {
        use rand::rngs::OsRng;
        
        let mut rng = OsRng;
        
        // Generate PQ keys (Kyber768)
        let (pq_public, pq_secret) = pqc_kyber::keypair(&mut rng);
        
        // Generate X25519 keys
        let mut ec_secret = X25519SecretKey::default();
        rng.fill_bytes(&mut ec_secret);
        let ec_public = x25519_dalek::PublicKey::from(&ec_secret);
        
        // Generate Ed25519 keys
        let identity_secret = ed25519_dalek::SigningKey::generate(&mut rng);
        let identity_public = identity_secret.verifying_key();
        
        Ok(Self {
            pq_public: pq_public.to_bytes(),
            pq_secret,
            ec_public: ec_public.to_bytes(),
            ec_secret,
            identity_public: identity_public.to_bytes(),
            identity_secret: identity_secret.to_bytes(),
        })
    }
    
    /// Sign data with identity key
    pub fn sign(&self, data: &[u8]) -> Ed25519Signature {
        let signing_key = ed25519_dalek::SigningKey::from_bytes(&self.identity_secret);
        signing_key.sign(data).to_bytes()
    }
    
    /// Verify signature
    pub fn verify(&self, data: &[u8], signature: &Ed25519Signature) -> Result<(), CryptoError> {
        use ed25519_dalek::Verifier;
        
        let verifying_key = ed25519_dalek::VerifyingKey::from_bytes(&self.identity_public)?;
        let sig = ed25519_dalek::Signature::from_bytes(signature);
        
        verifying_key.verify(data, &sig)?;
        Ok(())
    }
    
    /// Create a PreKey bundle
    pub fn create_prekey_bundle(&self, prekey_id: u32) -> PreKeyBundle {
        // Sign the prekey data
        let mut data_to_sign = Vec::new();
        data_to_sign.extend_from_slice(&self.pq_public);
        data_to_sign.extend_from_slice(&self.ec_public);
        
        let signature = self.sign(&data_to_sign);
        
        PreKeyBundle {
            prekey_id,
            pq_public: self.pq_public,
            ec_public: self.ec_public,
            signature,
        }
    }
    
    /// Get public identity as bytes for hashing
    pub fn public_identity(&self) -> Vec<u8> {
        let mut identity = Vec::new();
        identity.extend_from_slice(&self.pq_public);
        identity.extend_from_slice(&self.ec_public);
        identity.extend_from_slice(&self.identity_public);
        identity
    }
}

impl EphemeralKeys {
    /// Generate new ephemeral keys
    pub fn generate() -> Self {
        use rand::rngs::OsRng;
        
        let mut rng = OsRng;
        let mut ec_secret = X25519SecretKey::default();
        rng.fill_bytes(&mut ec_secret);
        
        let ec_public = x25519_dalek::PublicKey::from(&ec_secret);
        
        Self {
            ec_public: ec_public.to_bytes(),
            ec_secret,
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
    
    #[error("Signature verification failed: {0}")]
    Signature(String),
    
    #[error("Invalid key format: {0}")]
    InvalidKey(String),
    
    #[error("Random number generation failed: {0}")]
    Random(String),
}

impl From<ed25519_dalek::SignatureError> for CryptoError {
    fn from(err: ed25519_dalek::SignatureError) -> Self {
        CryptoError::Signature(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_identity_key_generation() {
        let identity = IdentityKeyPair::generate().unwrap();
        assert_eq!(identity.pq_public.len(), 1088);
        assert_eq!(identity.pq_secret.len(), 2400);
        assert_eq!(identity.ec_public.len(), 32);
        assert_eq!(identity.ec_secret.len(), 32);
        assert_eq!(identity.identity_public.len(), 32);
        assert_eq!(identity.identity_secret.len(), 64);
    }
    
    #[test]
    fn test_sign_verify() {
        let identity = IdentityKeyPair::generate().unwrap();
        let data = b"Hello, Liberty Reach!";
        
        let signature = identity.sign(data);
        assert!(identity.verify(data, &signature).is_ok());
        
        let bad_data = b"Hello, World!";
        assert!(identity.verify(bad_data, &signature).is_err());
    }
    
    #[test]
    fn test_prekey_bundle() {
        let identity = IdentityKeyPair::generate().unwrap();
        let bundle = identity.create_prekey_bundle(1);
        
        assert_eq!(bundle.prekey_id, 1);
        assert_eq!(bundle.pq_public.len(), 1088);
        assert_eq!(bundle.ec_public.len(), 32);
        assert_eq!(bundle.signature.len(), 64);
    }
}
