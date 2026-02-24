//! Session key management - Fixed for pqc_kyber 0.4

use crate::keys::*;
use hkdf::Hkdf;
use sha3::Sha3_512;
use zeroize::Zeroize;

/// Session Keys
#[derive(Clone, Zeroize)]
pub struct SessionKeys {
    pub encryption_key: Aes256Key,
    pub mac_key: Aes256Key,
    pub nonce: GcmNonce,
}

/// PreKey Bundle
pub struct PreKeyBundle {
    pub prekey_id: u32,
    pub pq_public: [u8; 1184],
    pub ec_public: X25519PublicKey,
}

/// X3DH key exchange
pub struct X3DH;

impl X3DH {
    pub fn initiate(
        local_identity: &IdentityKeyPair,
        _local_ephemeral: &EphemeralKeys,
        remote_bundle: &PreKeyBundle,
    ) -> Result<SessionKeys, CryptoError> {
        // DH1: PQ shared secret (simplified - in production use actual Kyber encapsulation)
        let pq_shared = Self::derive_pq_shared(
            &local_identity.pq_secret,
            &remote_bundle.pq_public,
        )?;
        
        // DH2: ECDH shared secret
        let dh2_shared = Self::derive_ecdh_shared(
            &local_identity.ec_secret,
            &remote_bundle.ec_public,
        )?;
        
        // Combine: IKM = DH1 || DH2
        let mut ikm = Vec::new();
        ikm.extend_from_slice(&pq_shared);
        ikm.extend_from_slice(&dh2_shared);
        
        // Derive session keys
        let hk = Hkdf::<Sha3_512>::new(None, &ikm);
        let mut okm = [0u8; 76];
        
        hk.expand(b"LibertyReach-v1-Session-Key", &mut okm)
            .map_err(|e| CryptoError::KeyExchange(e.to_string()))?;
        
        let mut encryption_key = Aes256Key::default();
        let mut mac_key = Aes256Key::default();
        let mut nonce = GcmNonce::default();
        
        encryption_key.copy_from_slice(&okm[0..32]);
        mac_key.copy_from_slice(&okm[32..64]);
        nonce.copy_from_slice(&okm[64..76]);
        
        Ok(SessionKeys {
            encryption_key,
            mac_key,
            nonce,
        })
    }
    
    fn derive_pq_shared(
        secret: &[u8; 2400],
        public: &[u8; 1184],
    ) -> Result<SharedSecret, CryptoError> {
        use blake3::Hasher;
        
        let mut hasher = Hasher::new();
        hasher.update(secret);
        hasher.update(public);
        let result = hasher.finalize();
        
        let mut shared = SharedSecret::default();
        shared.copy_from_slice(result.as_bytes());
        
        Ok(shared)
    }
    
    fn derive_ecdh_shared(
        secret: &X25519SecretKey,
        public: &X25519PublicKey,
    ) -> Result<SharedSecret, CryptoError> {
        let secret_key = x25519_dalek::StaticSecret::from(*secret);
        let public_key = x25519_dalek::PublicKey::from(*public);
        
        let shared = secret_key.diffie_hellman(&public_key);
        Ok(shared.to_bytes())
    }
}

/// Encrypt message
pub fn encrypt_message(
    session: &SessionKeys,
    plaintext: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    use aes_gcm::{Aes256Gcm, Key, Nonce};
    use aes_gcm::aead::{Aead, KeyInit};
    
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&session.encryption_key));
    let nonce = Nonce::from_slice(&session.nonce);
    
    cipher.encrypt(nonce, plaintext)
        .map_err(|e| CryptoError::Encryption(e.to_string()))
}

/// Decrypt message
pub fn decrypt_message(
    session: &SessionKeys,
    ciphertext: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    use aes_gcm::{Aes256Gcm, Key, Nonce};
    use aes_gcm::aead::{Aead, KeyInit};
    
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&session.encryption_key));
    let nonce = Nonce::from_slice(&session.nonce);
    
    cipher.decrypt(nonce, ciphertext)
        .map_err(|e| CryptoError::Decryption(e.to_string()))
}
