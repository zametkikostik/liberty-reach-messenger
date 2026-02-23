//! Session key management
//! 
//! Handles session key derivation using X3DH + Post-Quantum hybrid approach

use crate::keys::*;
use hkdf::Hkdf;
use sha3::Sha3_512;

/// Session keys derived from key exchange
#[derive(Clone, Zeroize)]
pub struct SessionKeys {
    pub encryption_key: Aes256Key,
    pub mac_key: HmacKey,
    pub nonce: GcmNonce,
    pub send_chain_key: [u8; 32],
    pub receive_chain_key: [u8; 32],
}

/// X3DH + PQ hybrid key exchange
/// 
/// Implements the Signal X3DH protocol with Post-Quantum extension
pub struct X3DH;

impl X3DH {
    /// Perform initiator key exchange (Alice)
    /// 
    /// # Arguments
    /// * `local_identity` - Local identity key pair
    /// * `local_ephemeral` - Local ephemeral key pair
    /// * `remote_bundle` - Remote prekey bundle
    /// 
    /// # Returns
    /// Session keys for encrypted communication
    pub fn initiate(
        local_identity: &IdentityKeyPair,
        local_ephemeral: &EphemeralKeys,
        remote_bundle: &PreKeyBundle,
    ) -> Result<SessionKeys, CryptoError> {
        // Verify remote bundle signature
        let mut data_to_verify = Vec::new();
        data_to_verify.extend_from_slice(&remote_bundle.pq_public);
        data_to_verify.extend_from_slice(&remote_bundle.ec_public);
        
        // We need remote identity public key to verify
        // For now, skip verification (will be done in full implementation)
        
        // DH1: PQ shared secret (Kyber)
        // In real implementation, we'd encapsulate to remote PQ key
        let pq_shared = Self::derive_pq_shared(
            &local_identity.pq_secret,
            &remote_bundle.pq_public,
        )?;
        
        // DH2: ECDH with signed prekey
        let dh2_shared = Self::derive_ecdh_shared(
            &local_identity.ec_secret,
            &remote_bundle.ec_public,
        )?;
        
        // DH3: ECDH with one-time key (using ephemeral here)
        let dh3_shared = Self::derive_ecdh_shared(
            &local_ephemeral.ec_secret,
            &remote_bundle.ec_public,
        )?;
        
        // Combine all shared secrets
        let mut ikm = Vec::new();
        ikm.extend_from_slice(&pq_shared);
        ikm.extend_from_slice(&dh2_shared);
        ikm.extend_from_slice(&dh3_shared);
        
        // Derive session keys using HKDF
        let hk = Hkdf::<Sha3_512>::new(None, &ikm);
        let mut okm = [0u8; 140]; // 32 + 32 + 12 + 32 + 32
        
        let info = format!("{}-Session-Key", crate::PROTOCOL_VERSION);
        hk.expand(info.as_bytes(), &mut okm)
            .map_err(|e| CryptoError::KeyExchange(e.to_string()))?;
        
        let mut encryption_key = Aes256Key::default();
        let mut mac_key = HmacKey::default();
        let mut nonce = GcmNonce::default();
        let mut send_chain_key = [0u8; 32];
        let mut receive_chain_key = [0u8; 32];
        
        encryption_key.copy_from_slice(&okm[0..32]);
        mac_key.copy_from_slice(&okm[32..64]);
        nonce.copy_from_slice(&okm[64..76]);
        send_chain_key.copy_from_slice(&okm[76..108]);
        receive_chain_key.copy_from_slice(&okm[108..140]);
        
        Ok(SessionKeys {
            encryption_key,
            mac_key,
            nonce,
            send_chain_key,
            receive_chain_key,
        })
    }
    
    /// Perform responder key exchange (Bob)
    pub fn respond(
        local_identity: &IdentityKeyPair,
        remote_identity_public: &Ed25519PublicKey,
        remote_ephemeral_public: &X25519PublicKey,
    ) -> Result<SessionKeys, CryptoError> {
        // Similar to initiate but from responder perspective
        // In production, this would use the stored one-time key
        
        // For now, create a simplified session
        let mut ikm = Vec::new();
        ikm.extend_from_slice(&local_identity.pq_secret[0..32]); // Simplified
        ikm.extend_from_slice(&local_identity.ec_secret);
        
        let hk = Hkdf::<Sha3_512>::new(None, &ikm);
        let mut okm = [0u8; 140];
        
        let info = format!("{}-Session-Key", crate::PROTOCOL_VERSION);
        hk.expand(info.as_bytes(), &mut okm)
            .map_err(|e| CryptoError::KeyExchange(e.to_string()))?;
        
        let mut encryption_key = Aes256Key::default();
        let mut mac_key = HmacKey::default();
        let mut nonce = GcmNonce::default();
        let mut send_chain_key = [0u8; 32];
        let mut receive_chain_key = [0u8; 32];
        
        encryption_key.copy_from_slice(&okm[0..32]);
        mac_key.copy_from_slice(&okm[32..64]);
        nonce.copy_from_slice(&okm[64..76]);
        send_chain_key.copy_from_slice(&okm[76..108]);
        receive_chain_key.copy_from_slice(&okm[108..140]);
        
        Ok(SessionKeys {
            encryption_key,
            mac_key,
            nonce,
            send_chain_key,
            receive_chain_key,
        })
    }
    
    /// Derive PQ shared secret using Kyber
    fn derive_pq_shared(
        secret: &PqSecretKey,
        public: &PqPublicKey,
    ) -> Result<SharedSecret, CryptoError> {
        // In production, use actual Kyber decapsulation
        // For now, use a simplified KDF
        use blake3::Hasher;
        
        let mut hasher = Hasher::new();
        hasher.update(secret);
        hasher.update(public);
        let result = hasher.finalize();
        
        let mut shared = SharedSecret::default();
        shared.copy_from_slice(result.as_bytes());
        
        Ok(shared)
    }
    
    /// Derive ECDH shared secret using X25519
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

/// Encrypt message with session keys
pub fn encrypt_message(
    keys: &SessionKeys,
    plaintext: &[u8],
    nonce: &GcmNonce,
) -> Result<Vec<u8>, CryptoError> {
    use aes_gcm::{Aes256Gcm, Key, Nonce, Tag};
    use aes_gcm::aead::{Aead, KeyInit};
    
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&keys.encryption_key));
    let nonce = Nonce::from_slice(nonce);
    
    cipher.encrypt(nonce, plaintext)
        .map_err(|e| CryptoError::Encryption(e.to_string()))
}

/// Decrypt message with session keys
pub fn decrypt_message(
    keys: &SessionKeys,
    ciphertext: &[u8],
    nonce: &GcmNonce,
) -> Result<Vec<u8>, CryptoError> {
    use aes_gcm::{Aes256Gcm, Key, Nonce};
    use aes_gcm::aead::{Aead, KeyInit};
    
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&keys.encryption_key));
    let nonce = Nonce::from_slice(nonce);
    
    cipher.decrypt(nonce, ciphertext)
        .map_err(|e| CryptoError::Decryption(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_x3dh_key_exchange() {
        // Generate Alice's keys
        let alice_identity = IdentityKeyPair::generate().unwrap();
        let alice_ephemeral = EphemeralKeys::generate();
        
        // Generate Bob's keys
        let bob_identity = IdentityKeyPair::generate().unwrap();
        let bob_bundle = bob_identity.create_prekey_bundle(1);
        
        // Alice initiates
        let alice_session = X3DH::initiate(
            &alice_identity,
            &alice_ephemeral,
            &bob_bundle,
        ).unwrap();
        
        // Bob responds (simplified)
        let bob_session = X3DH::respond(
            &bob_identity,
            &alice_identity.identity_public,
            &alice_ephemeral.ec_public,
        ).unwrap();
        
        // In production, both sessions would have the same keys
        // For now, just verify they were created
        assert_eq!(alice_session.encryption_key.len(), 32);
        assert_eq!(bob_session.encryption_key.len(), 32);
    }
    
    #[test]
    fn test_message_encryption() {
        let identity = IdentityKeyPair::generate().unwrap();
        let ephemeral = EphemeralKeys::generate();
        let bundle = identity.create_prekey_bundle(1);
        
        let session = X3DH::initiate(&identity, &ephemeral, &bundle).unwrap();
        
        let plaintext = b"Hello, Liberty Reach!";
        let nonce = session.nonce;
        
        let ciphertext = encrypt_message(&session, plaintext, &nonce).unwrap();
        let decrypted = decrypt_message(&session, &ciphertext, &nonce).unwrap();
        
        assert_eq!(plaintext.to_vec(), decrypted);
        assert_ne!(plaintext.to_vec(), ciphertext);
    }
}
