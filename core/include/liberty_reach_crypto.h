/**
 * Liberty Reach Crypto - C++ Header
 * 
 * Cryptographic module for TDLib integration
 * Provides Post-Quantum encryption, Steganography, and Profile Management
 */

#pragma once

#include <string>
#include <vector>
#include <array>
#include <memory>
#include <optional>

namespace td {
namespace liberty_reach {

// Type aliases for cryptographic primitives
using ByteArray = std::vector<std::uint8_t>;
using ByteSpan = std::span<const std::uint8_t>;

// Key sizes
constexpr std::size_t PQ_PUBLIC_KEY_SIZE = 1088;   // Kyber768
constexpr std::size_t PQ_SECRET_KEY_SIZE = 2400;   // Kyber768
constexpr std::size_t X25519_KEY_SIZE = 32;
constexpr std::size_t ED25519_PUBLIC_KEY_SIZE = 32;
constexpr std::size_t ED25519_SECRET_KEY_SIZE = 64;
constexpr std::size_t ED25519_SIGNATURE_SIZE = 64;
constexpr std::size_t AES256_KEY_SIZE = 32;
constexpr std::size_t GCM_NONCE_SIZE = 12;
constexpr std::size_t GCM_TAG_SIZE = 16;
constexpr std::size_t MASTER_KEY_SIZE = 32;
constexpr std::size_t SHAMIR_SHARE_SIZE = 32;

/**
 * Identity Key Pair - Long-term keys for a user
 */
struct IdentityKeyPair {
  std::array<std::uint8_t, PQ_PUBLIC_KEY_SIZE> pq_public;
  std::array<std::uint8_t, PQ_SECRET_KEY_SIZE> pq_secret;
  std::array<std::uint8_t, X25519_KEY_SIZE> ec_public;
  std::array<std::uint8_t, X25519_KEY_SIZE> ec_secret;
  std::array<std::uint8_t, ED25519_PUBLIC_KEY_SIZE> identity_public;
  std::array<std::uint8_t, ED25519_SECRET_KEY_SIZE> identity_secret;
};

/**
 * PreKey Bundle for X3DH key exchange
 */
struct PreKeyBundle {
  std::uint32_t prekey_id;
  std::array<std::uint8_t, PQ_PUBLIC_KEY_SIZE> pq_public;
  std::array<std::uint8_t, X25519_KEY_SIZE> ec_public;
  std::array<std::uint8_t, ED25519_SIGNATURE_SIZE> signature;
};

/**
 * One-Time Key
 */
struct OneTimeKey {
  std::uint32_t key_id;
  std::array<std::uint8_t, X25519_KEY_SIZE> public_key;
};

/**
 * Session Keys derived from key exchange
 */
struct SessionKeys {
  std::array<std::uint8_t, AES256_KEY_SIZE> encryption_key;
  std::array<std::uint8_t, AES256_KEY_SIZE> mac_key;
  std::array<std::uint8_t, GCM_NONCE_SIZE> nonce;
  std::array<std::uint8_t, 32> send_chain_key;
  std::array<std::uint8_t, 32> receive_chain_key;
  std::uint32_t send_counter = 0;
  std::uint32_t receive_counter = 0;
};

/**
 * Shamir Secret Share for profile recovery
 */
struct SecretShare {
  std::uint8_t id;
  std::vector<std::uint8_t> data;
};

/**
 * Profile Master Key - Never deleted
 */
struct ProfileMasterKey {
  std::array<std::uint8_t, MASTER_KEY_SIZE> key;
  std::uint64_t created_at;
  std::array<std::uint8_t, 32> recovery_hash;
  std::vector<SecretShare> recovery_shares;  // 5 shares, need 3 to recover
};

/**
 * Encrypted Profile
 */
struct EncryptedProfile {
  std::string user_id;
  ByteArray public_pq_key;
  ByteArray public_ec_key;
  ByteArray public_identity_key;
  ByteArray encrypted_data;
  std::string recovery_hash;
  std::uint64_t created_at;
  std::uint64_t last_seen;
  bool is_active = true;
};

/**
 * Message Header for ratcheted encryption
 */
struct MessageHeader {
  std::uint32_t counter;
  std::array<std::uint8_t, GCM_NONCE_SIZE> nonce;
  std::array<std::uint8_t, X25519_KEY_SIZE> ratchet_public;
};

/**
 * Crypto result type
 */
template<typename T>
using Result = std::expected<T, std::string>;

/**
 * Liberty Reach Cryptographic Engine
 * 
 * Main interface for all cryptographic operations
 */
class LibertyReachCrypto {
 public:
  LibertyReachCrypto() = default;
  ~LibertyReachCrypto() = default;

  // Non-copyable
  LibertyReachCrypto(const LibertyReachCrypto&) = delete;
  LibertyReachCrypto& operator=(const LibertyReachCrypto&) = delete;

  // Movable
  LibertyReachCrypto(LibertyReachCrypto&&) = default;
  LibertyReachCrypto& operator=(LibertyReachCrypto&&) = default;

  // ============================================
  // KEY GENERATION
  // ============================================

  /**
   * Generate new identity key pair
   * @return IdentityKeyPair or error
   */
  static Result<IdentityKeyPair> generate_identity_keys();

  /**
   * Generate ephemeral keys for X3DH
   * @return Ephemeral key pair (ec_public, ec_secret)
   */
  static Result<std::pair<ByteArray, ByteArray>> generate_ephemeral_keys();

  /**
   * Create PreKey bundle from identity
   * @param identity The identity key pair
   * @param prekey_id Unique identifier for this prekey
   * @return PreKeyBundle
   */
  static Result<PreKeyBundle> create_prekey_bundle(
      const IdentityKeyPair& identity,
      std::uint32_t prekey_id);

  // ============================================
  // KEY EXCHANGE (X3DH + PQ)
  // ============================================

  /**
   * Initiate X3DH key exchange (Alice's side)
   * @param local_identity Alice's identity keys
   * @param local_ephemeral Alice's ephemeral keys
   * @param remote_bundle Bob's PreKey bundle
   * @return SessionKeys for encrypted communication
   */
  static Result<SessionKeys> x3dh_initiate(
      const IdentityKeyPair& local_identity,
      const std::pair<ByteArray, ByteArray>& local_ephemeral,
      const PreKeyBundle& remote_bundle);

  /**
   * Respond to X3DH key exchange (Bob's side)
   * @param local_identity Bob's identity keys
   * @param remote_identity_public Alice's identity public key
   * @param remote_ephemeral_public Alice's ephemeral public key
   * @return SessionKeys
   */
  static Result<SessionKeys> x3dh_respond(
      const IdentityKeyPair& local_identity,
      ByteSpan remote_identity_public,
      ByteSpan remote_ephemeral_public);

  // ============================================
  // MESSAGE ENCRYPTION
  // ============================================

  /**
   * Encrypt message with session keys (AES-256-GCM)
   * @param session Session keys
   * @param plaintext Message to encrypt
   * @return Ciphertext (includes authentication tag)
   */
  static Result<ByteArray> encrypt_message(
      SessionKeys& session,
      ByteSpan plaintext);

  /**
   * Decrypt message with session keys
   * @param session Session keys
   * @param ciphertext Encrypted message (includes tag)
   * @return Plaintext or error
   */
  static Result<ByteArray> decrypt_message(
      SessionKeys& session,
      ByteSpan ciphertext);

  // ============================================
  // DOUBLE RATCHET
  // ============================================

  /**
   * Perform DH ratchet step
   * @param session Current session
   * @param remote_ratchet_public New ratchet public key from remote
   * @return Updated session
   */
  static Result<SessionKeys> dh_ratchet(
      SessionKeys& session,
      ByteSpan remote_ratchet_public);

  /**
   * Get next send key from chain
   * @param session Current session
   * @return Message key for encryption
   */
  static Result<ByteArray> next_send_key(SessionKeys& session);

  // ============================================
  // STEGANOGRAPHY
  // ============================================

  /**
   * Encode message in image using LSB steganography
   * @param message Message to hide
   * @param cover_image RGB/BGR image data
   * @param width Image width
   * @param height Image height
   * @return Stego image with hidden message
   */
  static Result<ByteArray> steganography_encode(
      ByteSpan message,
      ByteSpan cover_image,
      std::size_t width,
      std::size_t height);

  /**
   * Decode message from stego image
   * @param stego_image Image with hidden message
   * @param width Image width
   * @param height Image height
   * @return Hidden message
   */
  static Result<ByteArray> steganography_decode(
      ByteSpan stego_image,
      std::size_t width,
      std::size_t height);

  /**
   * Get maximum message size for an image
   */
  static std::size_t steganography_capacity(
      std::size_t width, std::size_t height);

  // ============================================
  // PROFILE MANAGEMENT (PERMANENT)
  // ============================================

  /**
   * Create new permanent profile
   * @param user_id Unique user identifier
   * @param identity User's identity keys
   * @return (EncryptedProfile, ProfileMasterKey)
   * 
   * IMPORTANT: Profile CANNOT be deleted, only deactivated
   */
  static Result<std::pair<EncryptedProfile, ProfileMasterKey>> 
  create_profile(
      std::string_view user_id,
      const IdentityKeyPair& identity);

  /**
   * Deactivate profile (temporary, reversible)
   * @param profile Profile to deactivate
   * @return Success or error
   */
  static Result<void> deactivate_profile(EncryptedProfile& profile);

  /**
   * Reactivate profile
   * @param profile Profile to reactivate
   * @return Success or error
   */
  static Result<void> reactivate_profile(EncryptedProfile& profile);

  /**
   * ⛔ Delete profile - NOT ALLOWED
   * Always returns error - profiles are permanent
   */
  static Result<void> delete_profile(std::string_view user_id) {
    return std::unexpected(
        "Profile deletion is NOT allowed. "
        "Profiles are permanent in Liberty Reach. "
        "Use deactivate_profile() instead.");
  }

  // ============================================
  // SHAMIR'S SECRET SHARING
  // ============================================

  /**
   * Split master key into N shares
   * @param key Master key to split
   * @param total_shares Total number of shares (e.g., 5)
   * @param threshold Minimum shares needed to recover (e.g., 3)
   * @return Vector of secret shares
   */
  static Result<std::vector<SecretShare>> split_secret(
      ByteSpan key,
      std::size_t total_shares,
      std::size_t threshold);

  /**
   * Recover master key from K shares
   * @param shares Secret shares (at least threshold)
   * @return Recovered master key
   */
  static Result<ByteArray> recover_secret(
      const std::vector<SecretShare>& shares);

  /**
   * Refresh shares without changing the secret
   * @param old_shares Current shares
   * @return New shares with same secret
   */
  static Result<std::vector<SecretShare>> refresh_shares(
      const std::vector<SecretShare>& old_shares);

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /**
   * Sign data with identity key (Ed25519)
   */
  static Result<ByteArray> sign(
      const IdentityKeyPair& identity,
      ByteSpan data);

  /**
   * Verify signature
   */
  static Result<bool> verify(
      ByteSpan identity_public,
      ByteSpan data,
      ByteSpan signature);

  /**
   * Generate random bytes
   */
  static ByteArray random_bytes(std::size_t size);

  /**
   * Compute BLAKE3 hash
   */
  static std::array<std::uint8_t, 32> blake3_hash(ByteSpan data);

  /**
   * Get protocol version string
   */
  static constexpr const char* protocol_version() {
    return "LibertyReach-v1";
  }

  /**
   * Get library version
   */
  static constexpr const char* version() {
    return "0.1.0";
  }
};

}  // namespace liberty_reach
}  // namespace td
