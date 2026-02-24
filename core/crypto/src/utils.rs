//! Utility functions - Working version

use rand::RngCore;

/// Generate random bytes
pub fn random_bytes<const N: usize>() -> [u8; N] {
    let mut bytes = [0u8; N];
    rand::thread_rng().fill_bytes(&mut bytes);
    bytes
}

/// Compute BLAKE3 hash
pub fn blake3_hash(data: &[u8]) -> [u8; 32] {
    use blake3::Hasher;
    let mut hasher = Hasher::new();
    hasher.update(data);
    hasher.finalize().as_bytes().clone()
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
