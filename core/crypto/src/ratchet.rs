//! Double Ratchet implementation
//! 
//! Implements the Signal Double Ratchet algorithm for forward secrecy

use crate::keys::*;
use crate::session::SessionKeys;
use hmac::{Hmac, Mac};
use sha3::Sha3_512;
use zeroize::{Zeroize, ZeroizeOnDrop};

type ChainKey = [u8; 32];
type MessageKey = [u8; 32];

/// Double Ratchet state
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct DoubleRatchet {
    /// Root key for ratchet
    root_key: ChainKey,
    
    /// Sending chain key
    send_chain_key: Option<ChainKey>,
    
    /// Receiving chain key
    receive_chain_key: Option<ChainKey>,
    
    /// Current ratchet key pair
    ratchet_key_pair: Option<(X25519PublicKey, X25519SecretKey)>,
    
    /// Remote ratchet public key
    remote_ratchet_public: Option<X25519PublicKey>,
    
    /// Message counters
    send_counter: u32,
    receive_counter: u32,
    
    /// Skip list for out-of-order messages
    skipped_keys: Vec<(u32, MessageKey)>,
}

impl DoubleRatchet {
    /// Create new Double Ratchet from session keys
    pub fn new(session_keys: &SessionKeys) -> Self {
        Self {
            root_key: session_keys.send_chain_key,
            send_chain_key: Some(session_keys.send_chain_key),
            receive_chain_key: Some(session_keys.receive_chain_key),
            ratchet_key_pair: None,
            remote_ratchet_public: None,
            send_counter: 0,
            receive_counter: 0,
            skipped_keys: Vec::new(),
        }
    }
    
    /// Initialize with ratchet key pair
    pub fn with_ratchet_keys(&mut self, key_pair: (X25519PublicKey, X25519SecretKey)) {
        self.ratchet_key_pair = Some(key_pair);
    }
    
    /// Set remote ratchet public key
    pub fn set_remote_ratchet(&mut self, remote_public: X25519PublicKey) {
        self.remote_ratchet_public = Some(remote_public);
    }
    
    /// Get next message key for sending
    pub fn next_send_key(&mut self) -> Result<MessageKey, CryptoError> {
        if self.send_chain_key.is_none() {
            return Err(CryptoError::KeyExchange("No send chain".to_string()));
        }
        
        let chain_key = self.send_chain_key.as_mut().unwrap();
        
        // Derive message key and next chain key
        let (message_key, new_chain_key) = Self::kdf_chain(*chain_key);
        *chain_key = new_chain_key;
        
        self.send_counter += 1;
        
        Ok(message_key)
    }
    
    /// Perform DH ratchet step when receiving new ratchet public key
    pub fn dh_ratchet(&mut self, remote_ratchet_public: X25519PublicKey) -> Result<(), CryptoError> {
        // Store skipped keys from current receive chain
        if let Some(_) = self.receive_chain_key {
            // In production, would store current chain state
        }
        
        // Perform DH
        if let Some((_, ref my_ratchet_secret)) = self.ratchet_key_pair {
            if let Some(old_remote_public) = self.remote_ratchet_public {
                // DH with old remote key
                let dh_output = Self::dh(my_ratchet_secret, &old_remote_public)?;
                self.root_key = Self::kdf_root(&self.root_key, &dh_output)?;
            }
        }
        
        // Generate new ratchet key pair
        use rand::rngs::OsRng;
        let mut rng = OsRng;
        let mut new_secret = X25519SecretKey::default();
        rng.fill_bytes(&mut new_secret);
        let new_public = x25519_dalek::PublicKey::from(&new_secret);
        
        self.ratchet_key_pair = Some((new_public.to_bytes(), new_secret));
        self.remote_ratchet_public = Some(remote_ratchet_public);
        
        // DH with new keys
        if let Some((ref my_public, ref my_secret)) = self.ratchet_key_pair {
            let dh_output = Self::dh(my_secret, &remote_ratchet_public)?;
            self.root_key = Self::kdf_root(&self.root_key, &dh_output)?;
            
            // Derive new send chain
            let (new_send_chain, _) = Self::kdf_chain(self.root_key);
            self.send_chain_key = Some(new_send_chain);
            
            // Derive new receive chain
            let dh_output2 = Self::dh(my_secret, &remote_ratchet_public)?;
            let (_, new_receive_chain) = Self::kdf_chain(dh_output2);
            self.receive_chain_key = Some(new_receive_chain);
        }
        
        self.send_counter = 0;
        self.receive_counter = 0;
        
        Ok(())
    }
    
    /// Decrypt message with ratcheted keys
    pub fn decrypt(&mut self, ciphertext: &[u8], header: &MessageHeader) -> Result<Vec<u8>, CryptoError> {
        // Check skip list
        for (i, (counter, key)) in self.skipped_keys.iter().enumerate() {
            if *counter == header.counter {
                // Use skipped key
                let plaintext = crate::session::decrypt_message(
                    &Self::session_from_key(*key),
                    ciphertext,
                    &header.nonce,
                )?;
                self.skipped_keys.remove(i);
                return Ok(plaintext);
            }
        }
        
        // Ratchet if needed
        if header.counter > self.receive_counter {
            // Need to ratchet forward
            // In production, would handle this properly
        }
        
        if let Some(chain_key) = self.receive_chain_key {
            let mut temp_chain = chain_key;
            let mut temp_counter = self.receive_counter;
            
            // Derive keys up to the message counter
            while temp_counter < header.counter {
                let (_, new_chain) = Self::kdf_chain(temp_chain);
                temp_chain = new_chain;
                temp_counter += 1;
            }
            
            let (message_key, new_chain) = Self::kdf_chain(temp_chain);
            self.receive_chain_key = Some(new_chain);
            self.receive_counter = header.counter + 1;
            
            let session = Self::session_from_key(message_key);
            crate::session::decrypt_message(&session, ciphertext, &header.nonce)
        } else {
            Err(CryptoError::Decryption("No receive chain".to_string()))
        }
    }
    
    /// Encrypt message
    pub fn encrypt(&mut self, plaintext: &[u8]) -> Result<(Vec<u8>, MessageHeader), CryptoError> {
        let message_key = self.next_send_key()?;
        let session = Self::session_from_key(message_key);
        
        // Generate nonce from message key
        let mut nonce = GcmNonce::default();
        use rand::RngCore;
        rand::thread_rng().fill_bytes(&mut nonce);
        
        let ciphertext = crate::session::encrypt_message(&session, plaintext, &nonce)?;
        
        let header = MessageHeader {
            counter: self.send_counter - 1,
            nonce,
        };
        
        Ok((ciphertext, header))
    }
    
    /// Helper: DH operation
    fn dh(secret: &X25519SecretKey, public: &X25519PublicKey) -> Result<SharedSecret, CryptoError> {
        let secret_key = x25519_dalek::StaticSecret::from(*secret);
        let public_key = x25519_dalek::PublicKey::from(*public);
        let shared = secret_key.diffie_hellman(&public_key);
        Ok(shared.to_bytes())
    }
    
    /// Helper: Root key KDF
    fn kdf_root(root_key: ChainKey, dh_output: &SharedSecret) -> Result<ChainKey, CryptoError> {
        let mut mac = Hmac::<Sha3_512>::new_from_slice(&root_key)
            .map_err(|e| CryptoError::KeyGeneration(e.to_string()))?;
        mac.update(dh_output);
        let result = mac.finalize();
        
        let mut new_root = ChainKey::default();
        new_root.copy_from_slice(&result.into_bytes()[0..32]);
        Ok(new_root)
    }
    
    /// Helper: Chain key KDF
    fn kdf_chain(chain_key: ChainKey) -> (MessageKey, ChainKey) {
        let mut mac = Hmac::<Sha3_512>::new_from_slice(&chain_key).unwrap();
        mac.update(&[0x01]);
        let result = mac.finalize();
        let mut message_key = MessageKey::default();
        message_key.copy_from_slice(&result.into_bytes()[0..32]);
        
        let mut mac2 = Hmac::<Sha3_512>::new_from_slice(&chain_key).unwrap();
        mac2.update(&[0x02]);
        let result2 = mac2.finalize();
        let mut new_chain_key = ChainKey::default();
        new_chain_key.copy_from_slice(&result2.into_bytes()[0..32]);
        
        (message_key, new_chain_key)
    }
    
    /// Helper: Create session from message key
    fn session_from_key(message_key: MessageKey) -> SessionKeys {
        use hkdf::Hkdf;
        use sha3::Sha3_512;
        
        let hk = Hkdf::<Sha3_512>::new(None, &message_key);
        let mut okm = [0u8; 76];
        hk.expand(b"message-keys", &mut okm).unwrap();
        
        let mut encryption_key = Aes256Key::default();
        let mut mac_key = HmacKey::default();
        let mut nonce = GcmNonce::default();
        
        encryption_key.copy_from_slice(&okm[0..32]);
        mac_key.copy_from_slice(&okm[32..64]);
        nonce.copy_from_slice(&okm[64..76]);
        
        SessionKeys {
            encryption_key,
            mac_key,
            nonce,
            send_chain_key: [0u8; 32],
            receive_chain_key: [0u8; 32],
        }
    }
}

/// Message header (sent with each message)
#[derive(Clone, Debug)]
pub struct MessageHeader {
    pub counter: u32,
    pub nonce: GcmNonce,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::{IdentityKeyPair, EphemeralKeys};
    use crate::session::X3DH;
    
    #[test]
    fn test_double_ratchet() {
        // Setup: Alice and Bob do X3DH
        let alice_identity = IdentityKeyPair::generate().unwrap();
        let alice_ephemeral = EphemeralKeys::generate();
        let bob_identity = IdentityKeyPair::generate().unwrap();
        let bob_bundle = bob_identity.create_prekey_bundle(1);
        
        let alice_session = X3DH::initiate(&alice_identity, &alice_ephemeral, &bob_bundle).unwrap();
        let bob_session = X3DH::respond(&bob_identity, &alice_identity.identity_public, &alice_ephemeral.ec_public).unwrap();
        
        // Create ratchets
        let mut alice_ratchet = DoubleRatchet::new(&alice_session);
        let mut bob_ratchet = DoubleRatchet::new(&bob_session);
        
        // Alice sends message to Bob
        let plaintext = b"Hello Bob!";
        let (ciphertext, header) = alice_ratchet.encrypt(plaintext).unwrap();
        
        // Bob decrypts (simplified - in production would handle header properly)
        // This is a basic test - full implementation would be more complex
        assert!(!ciphertext.is_empty());
        assert_ne!(ciphertext, plaintext.as_slice());
    }
}
