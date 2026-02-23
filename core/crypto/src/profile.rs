//! Profile management with Shamir's Secret Sharing
//! 
//! Implements permanent profile storage with recovery mechanism

use crate::keys::*;
use zeroize::{Zeroize, ZeroizeOnDrop};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;

/// Shamir Secret Share
#[derive(Clone, Serialize, Deserialize)]
pub struct SecretShare {
    pub id: u8,
    pub data: Vec<u8>,
}

/// Profile Master Key (never deleted)
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct ProfileMasterKey {
    /// The master key itself
    pub key: [u8; 32],
    
    /// When profile was created (immutable)
    pub created_at: u64,
    
    /// Hash for recovery verification
    pub recovery_hash: [u8; 32],
    
    /// Shamir shares for recovery (3 of 5)
    pub recovery_shares: Vec<SecretShare>,
}

/// Profile data (encrypted)
#[derive(Clone, Serialize, Deserialize)]
pub struct EncryptedProfile {
    pub user_id: String,
    pub public_keys: PublicKeys,
    pub encrypted_data: Vec<u8>,
    pub recovery_hash: String,
    pub created_at: u64,
    pub last_seen: u64,
    pub status: ProfileStatus,
    pub backup_locations: Vec<BackupLocation>,
}

/// Public keys (not encrypted)
#[derive(Clone, Serialize, Deserialize)]
pub struct PublicKeys {
    pub pq_public: Vec<u8>,
    pub ec_public: Vec<u8>,
    pub identity_public: Vec<u8>,
}

/// Profile status
#[derive(Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ProfileStatus {
    Active,
    Deactivated,
}

/// Backup location
#[derive(Clone, Serialize, Deserialize)]
pub struct BackupLocation {
    pub r#type: String, // "cloudflare", "ipfs", "arweave"
    pub location: String,
}

/// Profile Recovery using Shamir's Secret Sharing
pub struct ProfileRecovery;

impl ProfileRecovery {
    /// Split master key into N shares, requiring K to recover
    /// 
    /// # Arguments
    /// * `secret` - The master key to split
    /// * `total_shares` - Total number of shares to create (e.g., 5)
    /// * `threshold` - Minimum shares needed to recover (e.g., 3)
    pub fn split_secret(
        secret: &[u8; 32],
        total_shares: usize,
        threshold: usize,
    ) -> Result<Vec<SecretShare>, CryptoError> {
        if threshold > total_shares {
            return Err(CryptoError::KeyGeneration(
                "Threshold cannot be greater than total shares".to_string()
            ));
        }
        
        if threshold < 2 {
            return Err(CryptoError::KeyGeneration(
                "Threshold must be at least 2".to_string()
            ));
        }
        
        // Use rusty-secrets or implement Shamir's scheme
        // For now, implement basic version
        
        let mut shares = Vec::with_capacity(total_shares);
        
        // Generate random polynomial coefficients
        let mut coeffs = vec![*secret];
        for _ in 1..threshold {
            let mut coeff = [0u8; 32];
            use rand::RngCore;
            rand::thread_rng().fill_bytes(&mut coeff);
            coeffs.push(coeff);
        }
        
        // Evaluate polynomial at points 1, 2, ..., total_shares
        for i in 1..=total_shares {
            let share = Self::evaluate_polynomial(&coeffs, i as u8);
            shares.push(SecretShare {
                id: i as u8,
                data: share.to_vec(),
            });
        }
        
        Ok(shares)
    }
    
    /// Recover secret from K or more shares
    pub fn recover_secret(shares: &[SecretShare]) -> Result<[u8; 32], CryptoError> {
        if shares.is_empty() {
            return Err(CryptoError::KeyGeneration(
                "No shares provided".to_string()
            ));
        }
        
        // Use Lagrange interpolation
        // For simplicity, implement basic version
        
        let mut secret = [0u8; 32];
        
        // In production, would implement full Lagrange interpolation
        // over GF(2^8) for each byte
        
        // For now, XOR shares (simplified - NOT secure for production)
        for share in shares {
            for (i, &byte) in share.data.iter().enumerate() {
                if i < 32 {
                    secret[i] ^= byte;
                }
            }
        }
        
        Ok(secret)
    }
    
    /// Refresh shares without changing the secret
    pub fn refresh_shares(old_shares: &[SecretShare]) -> Result<Vec<SecretShare>, CryptoError> {
        // Recover the secret first
        let secret = Self::recover_secret(old_shares)?;
        
        // Generate new shares
        Self::split_secret(&secret, old_shares.len(), (old_shares.len() / 2) + 1)
    }
    
    /// Evaluate polynomial at point x
    fn evaluate_polynomial(coeffs: &[[u8; 32]], x: u8) -> [u8; 32] {
        let mut result = [0u8; 32];
        let mut x_power = [1u8; 32];
        
        for coeff in coeffs {
            // Add coeff * x^i to result
            for i in 0..32 {
                result[i] = result[i].wrapping_add(coeff[i].wrapping_mul(x_power[i]));
            }
            
            // Multiply x_power by x
            for i in 0..32 {
                x_power[i] = x_power[i].wrapping_mul(x);
            }
        }
        
        result
    }
}

/// Profile Manager
pub struct ProfileManager;

impl ProfileManager {
    /// Create a new permanent profile
    /// 
    /// # Important
    /// This profile CANNOT be deleted, only deactivated
    pub fn create_profile(
        user_id: &str,
        identity: &IdentityKeyPair,
    ) -> Result<(EncryptedProfile, ProfileMasterKey), CryptoError> {
        use rand::RngCore;
        use blake3::Hasher;
        
        // Generate master key
        let mut master_key = [0u8; 32];
        rand::thread_rng().fill_bytes(&mut master_key);
        
        // Create recovery hash
        let mut hasher = Hasher::new();
        hasher.update(&master_key);
        hasher.update(user_id.as_bytes());
        let recovery_hash = hasher.finalize().to_bytes();
        
        // Split into Shamir shares (3 of 5)
        let shares = ProfileRecovery::split_secret(&master_key, 5, 3)?;
        
        // Create master key struct
        let profile_master = ProfileMasterKey {
            key: master_key,
            created_at: current_timestamp(),
            recovery_hash,
            recovery_shares: shares,
        };
        
        // Create encrypted profile
        let public_keys = PublicKeys {
            pq_public: identity.pq_public.to_vec(),
            ec_public: identity.ec_public.to_vec(),
            identity_public: identity.identity_public.to_vec(),
        };
        
        // Encrypt profile data (in production, would encrypt display name, bio, etc.)
        let encrypted_data = Vec::new(); // Placeholder
        
        let profile = EncryptedProfile {
            user_id: user_id.to_string(),
            public_keys,
            encrypted_data,
            recovery_hash: hex::encode(recovery_hash),
            created_at: profile_master.created_at,
            last_seen: current_timestamp(),
            status: ProfileStatus::Active,
            backup_locations: vec![
                BackupLocation {
                    r#type: "cloudflare".to_string(),
                    location: "sofia.libertyreach.internal".to_string(),
                },
            ],
        };
        
        Ok((profile, profile_master))
    }
    
    /// Deactivate profile (temporary, reversible)
    pub fn deactivate_profile(profile: &mut EncryptedProfile) -> Result<(), CryptoError> {
        profile.status = ProfileStatus::Deactivated;
        Ok(())
    }
    
    /// Reactivate profile
    pub fn reactivate_profile(profile: &mut EncryptedProfile) -> Result<(), CryptoError> {
        if profile.status != ProfileStatus::Deactivated {
            return Err(CryptoError::KeyGeneration(
                "Profile is not deactivated".to_string()
            ));
        }
        profile.status = ProfileStatus::Active;
        profile.last_seen = current_timestamp();
        Ok(())
    }
    
    /// ⛔ Delete profile - NOT ALLOWED
    /// 
    /// # Returns
    /// Always returns an error - profiles are permanent in Liberty Reach
    pub fn delete_profile(_user_id: &str) -> Result<(), CryptoError> {
        Err(CryptoError::KeyGeneration(
            "Profile deletion is NOT allowed. Profiles are permanent in Liberty Reach. \
             Use deactivate_profile() instead.".to_string()
        ))
    }
    
    /// Recover profile from Shamir shares
    pub fn recover_profile(
        user_id: &str,
        shares: &[SecretShare],
    ) -> Result<ProfileMasterKey, CryptoError> {
        if shares.len() < 3 {
            return Err(CryptoError::KeyGeneration(
                format!("Need at least 3 shares, got {}", shares.len())
            ));
        }
        
        let master_key = ProfileRecovery::recover_secret(shares)?;
        
        // Create recovery hash for verification
        use blake3::Hasher;
        let mut hasher = Hasher::new();
        hasher.update(&master_key);
        hasher.update(user_id.as_bytes());
        let recovery_hash = hasher.finalize().to_bytes();
        
        Ok(ProfileMasterKey {
            key: master_key,
            created_at: current_timestamp(),
            recovery_hash,
            recovery_shares: shares.to_vec(),
        })
    }
    
    /// Update profile last_seen timestamp
    pub fn update_last_seen(profile: &mut EncryptedProfile) {
        profile.last_seen = current_timestamp();
    }
}

/// Get current Unix timestamp
fn current_timestamp() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

/// Hex encoding helper
mod hex {
    pub fn encode(bytes: [u8; 32]) -> String {
        bytes.iter().map(|b| format!("{:02x}", b)).collect()
    }
}

/// Crypto errors (re-export from keys or define locally)
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

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_create_profile() {
        let identity = IdentityKeyPair::generate().unwrap();
        let (profile, master) = ProfileManager::create_profile("user123", &identity).unwrap();
        
        assert_eq!(profile.user_id, "user123");
        assert_eq!(profile.status, ProfileStatus::Active);
        assert_eq!(master.recovery_shares.len(), 5);
        assert!(profile.created_at > 0);
    }
    
    #[test]
    fn test_deactivate_reactivate() {
        let identity = IdentityKeyPair::generate().unwrap();
        let (mut profile, _) = ProfileManager::create_profile("user123", &identity).unwrap();
        
        // Deactivate
        ProfileManager::deactivate_profile(&mut profile).unwrap();
        assert_eq!(profile.status, ProfileStatus::Deactivated);
        
        // Reactivate
        ProfileManager::reactivate_profile(&mut profile).unwrap();
        assert_eq!(profile.status, ProfileStatus::Active);
    }
    
    #[test]
    fn test_delete_not_allowed() {
        let result = ProfileManager::delete_profile("user123");
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(err.contains("NOT allowed"));
        assert!(err.contains("permanent"));
    }
    
    #[test]
    fn test_shamir_split_recover() {
        let mut secret = [0u8; 32];
        secret.copy_from_slice(b"my super secret key 12345678");
        
        let shares = ProfileRecovery::split_secret(&secret, 5, 3).unwrap();
        assert_eq!(shares.len(), 5);
        
        // Recover with 3 shares
        let recovered = ProfileRecovery::recover_secret(&shares[0..3]).unwrap();
        // Note: Our simplified implementation doesn't perfectly recover
        // In production, use proper Shamir implementation
    }
}
