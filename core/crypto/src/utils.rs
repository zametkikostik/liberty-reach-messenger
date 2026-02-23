//! Utility functions

use rand::RngCore;

/// Generate random bytes
pub fn random_bytes<const N: usize>() -> [u8; N] {
    let mut bytes = [0u8; N];
    rand::thread_rng().fill_bytes(&mut bytes);
    bytes
}

/// Generate random vector of bytes
pub fn random_vec(len: usize) -> Vec<u8> {
    let mut bytes = vec![0u8; len];
    rand::thread_rng().fill_bytes(&mut bytes);
    bytes
}

/// Constant-time comparison
pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    
    subtle::ConstantTimeEq::ct_eq(a, b).into()
}

/// HKDF wrapper
pub fn hkdf_expand(ikm: &[u8], info: &[u8], len: usize) -> Vec<u8> {
    use hkdf::Hkdf;
    use sha3::Sha3_512;
    
    let hk = Hkdf::<Sha3_512>::new(None, ikm);
    let mut okm = vec![0u8; len];
    hk.expand(info, &mut okm).expect("HKDF expand failed");
    okm
}

/// Compute BLAKE3 hash
pub fn blake3_hash(data: &[u8]) -> [u8; 32] {
    use blake3::Hasher;
    let mut hasher = Hasher::new();
    hasher.update(data);
    hasher.finalize().as_bytes().clone()
}

/// Compute SHA3-512 hash
pub fn sha3_512_hash(data: &[u8]) -> [u8; 64] {
    use sha3::{Digest, Sha3_512};
    let mut hasher = Sha3_512::new();
    hasher.update(data);
    hasher.finalize().into()
}

/// Base64 encode
pub fn base64_encode(data: &[u8]) -> String {
    use base64::{Engine, engine::general_purpose};
    general_purpose::STANDARD.encode(data)
}

/// Base64 decode
pub fn base64_decode(s: &str) -> Result<Vec<u8>, base64::DecodeError> {
    use base64::{Engine, engine::general_purpose};
    general_purpose::STANDARD.decode(s)
}

/// Hex encode
pub fn hex_encode(data: &[u8]) -> String {
    data.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Hex decode
pub fn hex_decode(s: &str) -> Result<Vec<u8>, std::num::ParseIntError> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_random_bytes() {
        let bytes1 = random_bytes::<32>();
        let bytes2 = random_bytes::<32>();
        assert_ne!(bytes1, bytes2);
    }
    
    #[test]
    fn test_constant_time_eq() {
        let a = b"hello";
        let b = b"hello";
        let c = b"world";
        
        assert!(constant_time_eq(a, b));
        assert!(!constant_time_eq(a, c));
    }
    
    #[test]
    fn test_hash_functions() {
        let data = b"test data";
        
        let hash1 = blake3_hash(data);
        let hash2 = blake3_hash(data);
        assert_eq!(hash1, hash2);
        
        let hash3 = blake3_hash(b"different data");
        assert_ne!(hash1, hash3);
    }
    
    #[test]
    fn test_base64_roundtrip() {
        let data = b"Hello, Liberty Reach!";
        let encoded = base64_encode(data);
        let decoded = base64_decode(&encoded).unwrap();
        assert_eq!(data.to_vec(), decoded);
    }
    
    #[test]
    fn test_hex_roundtrip() {
        let data = b"Hello, Liberty Reach!";
        let encoded = hex_encode(data);
        let decoded = hex_decode(&encoded).unwrap();
        assert_eq!(data.to_vec(), decoded);
    }
}
