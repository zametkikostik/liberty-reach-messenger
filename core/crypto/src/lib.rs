//! Liberty Reach Cryptographic Core
//! 
//! This crate provides the cryptographic primitives for Liberty Reach Messenger:
//! - Post-Quantum Key Exchange (CRYSTALS-Kyber)
//! - Classical ECDH (X25519, X448)
//! - Symmetric Encryption (AES-256-GCM, ChaCha20-Poly1305)
//! - Digital Signatures (Ed25519, Ed448)
//! - Shamir's Secret Sharing for profile recovery
//! - Double Ratchet for key evolution

#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]
#![allow(clippy::missing_errors_doc)]

pub mod keys;
pub mod session;
pub mod ratchet;
pub mod profile;
pub mod steganography;
pub mod utils;

pub use keys::*;
pub use session::*;
pub use ratchet::*;
pub use profile::*;

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Protocol version
pub const PROTOCOL_VERSION: &str = "LibertyReach-v1";
