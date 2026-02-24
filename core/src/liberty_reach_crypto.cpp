/**
 * Liberty Reach Crypto - C++ Implementation
 * 
 * Main cryptographic engine implementation
 */

#include "liberty_reach_crypto.h"

#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <sodium.h>
#include <blake3.h>
// #include <pqcrypto/kyber/kyber768.h>  // Not available, using Rust implementation

#include <random>
#include <cstring>
#include <algorithm>

namespace td {
namespace liberty_reach {

namespace {

// Helper: Generate random bytes
void random_fill(void* buffer, std::size_t size) {
  if (RAND_bytes(static_cast<unsigned char*>(buffer), static_cast<int>(size)) != 1) {
    // Fallback to sodium
    randombytes_buf(buffer, size);
  }
}

// Helper: Constant-time comparison
bool constant_time_eq(ByteSpan a, ByteSpan b) {
  if (a.size() != b.size()) {
    return false;
  }
  return sodium_memcmp(a.data(), b.data(), a.size()) == 0;
}

// Helper: HKDF using SHA3-512
void hkdf_expand(
    const std::uint8_t* ikm, std::size_t ikm_len,
    const std::uint8_t* info, std::size_t info_len,
    std::uint8_t* okm, std::size_t okm_len) {
  
  EVP_PKEY_CTX* pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_HKDF, nullptr);
  
  EVP_PKEY_derive_init(pctx);
  EVP_PKEY_CTX_set_hkdf_md(pctx, EVP_sha3_512());
  EVP_PKEY_CTX_set1_hkdf_salt(pctx, nullptr, 0);
  EVP_PKEY_CTX_set1_hkdf_key(pctx, ikm, static_cast<int>(ikm_len));
  EVP_PKEY_CTX_add1_hkdf_info(pctx, info, static_cast<int>(info_len));
  
  std::size_t out_len = okm_len;
  EVP_PKEY_derive(pctx, okm, &out_len);
  EVP_PKEY_CTX_free(pctx);
}

}  // namespace

// ============================================
// KEY GENERATION
// ============================================

Result<IdentityKeyPair> LibertyReachCrypto::generate_identity_keys() {
  IdentityKeyPair keys;
  
  // Generate PQ keys (Kyber768)
  if (pqcrypto_kyber768_keypair(
          keys.pq_public.data(), keys.pq_secret.data()) != 0) {
    return std::unexpected("Kyber key generation failed");
  }
  
  // Generate X25519 keys
  if (crypto_kx_keypair(
          keys.ec_public.data(), keys.ec_secret.data()) != 0) {
    return std::unexpected("X25519 key generation failed");
  }
  
  // Generate Ed25519 keys
  if (crypto_sign_keypair(
          keys.identity_public.data(), keys.identity_secret.data()) != 0) {
    return std::unexpected("Ed25519 key generation failed");
  }
  
  return keys;
}

Result<std::pair<ByteArray, ByteArray>> LibertyReachCrypto::generate_ephemeral_keys() {
  ByteArray ec_public(X25519_KEY_SIZE);
  ByteArray ec_secret(X25519_KEY_SIZE);
  
  if (crypto_kx_keypair(
          reinterpret_cast<unsigned char*>(ec_public.data()),
          reinterpret_cast<unsigned char*>(ec_secret.data())) != 0) {
    return std::unexpected("Ephemeral key generation failed");
  }
  
  return std::make_pair(ec_public, ec_secret);
}

Result<PreKeyBundle> LibertyReachCrypto::create_prekey_bundle(
    const IdentityKeyPair& identity,
    std::uint32_t prekey_id) {
  
  PreKeyBundle bundle;
  bundle.prekey_id = prekey_id;
  bundle.pq_public = identity.pq_public;
  bundle.ec_public = identity.ec_public;
  
  // Sign the prekey data
  std::vector<std::uint8_t> data_to_sign;
  data_to_sign.insert(data_to_sign.end(), 
                      identity.pq_public.begin(), identity.pq_public.end());
  data_to_sign.insert(data_to_sign.end(),
                      identity.ec_public.begin(), identity.ec_public.end());
  
  std::size_t sig_len;
  crypto_sign_signature(
      bundle.signature.data(), &sig_len,
      data_to_sign.data(), data_to_sign.size(),
      identity.identity_secret.data());
  
  return bundle;
}

// ============================================
// KEY EXCHANGE (X3DH + PQ)
// ============================================

Result<SessionKeys> LibertyReachCrypto::x3dh_initiate(
    const IdentityKeyPair& local_identity,
    const std::pair<ByteArray, ByteArray>& local_ephemeral,
    const PreKeyBundle& remote_bundle) {
  
  // Verify remote bundle signature (simplified - need remote identity public)
  // In production, would verify here
  
  // DH1: PQ shared secret (Kyber)
  // Note: In real implementation, would encapsulate to remote PQ key
  ByteArray pq_shared(32);
  blake3_state hasher;
  blake3_init(&hasher);
  blake3_update(&hasher, local_identity.pq_secret.data(), local_identity.pq_secret.size());
  blake3_update(&hasher, remote_bundle.pq_public.data(), remote_bundle.pq_public.size());
  blake3_final(&hasher, pq_shared.data(), pq_shared.size());
  
  // DH2: ECDH with signed prekey
  ByteArray dh2_shared(X25519_KEY_SIZE);
  if (crypto_kx_client_session_keys(
          dh2_shared.data(), nullptr,
          local_identity.ec_secret.data(),
          remote_bundle.ec_public.data()) != 0) {
    return std::unexpected("ECDH key exchange failed");
  }
  
  // DH3: ECDH with one-time key (using ephemeral here)
  ByteArray dh3_shared(X25519_KEY_SIZE);
  if (crypto_kx_client_session_keys(
          dh3_shared.data(), nullptr,
          local_ephemeral.second.data(),
          remote_bundle.ec_public.data()) != 0) {
    return std::unexpected("ECDH OTK exchange failed");
  }
  
  // Combine: IKM = DH1 || DH2 || DH3
  std::vector<std::uint8_t> ikm;
  ikm.insert(ikm.end(), pq_shared.begin(), pq_shared.end());
  ikm.insert(ikm.end(), dh2_shared.begin(), dh2_shared.end());
  ikm.insert(ikm.end(), dh3_shared.begin(), dh3_shared.end());
  
  // Derive session keys using HKDF
  SessionKeys session;
  std::vector<std::uint8_t> okm(140);  // 32 + 32 + 12 + 32 + 32
  
  std::string info = std::string(protocol_version()) + "-Session-Key";
  hkdf_expand(ikm.data(), ikm.size(),
              reinterpret_cast<const std::uint8_t*>(info.c_str()), info.size(),
              okm.data(), okm.size());
  
  std::memcpy(session.encryption_key.data(), okm.data(), AES256_KEY_SIZE);
  std::memcpy(session.mac_key.data(), okm.data() + 32, AES256_KEY_SIZE);
  std::memcpy(session.nonce.data(), okm.data() + 64, GCM_NONCE_SIZE);
  std::memcpy(session.send_chain_key.data(), okm.data() + 76, 32);
  std::memcpy(session.receive_chain_key.data(), okm.data() + 108, 32);
  
  return session;
}

Result<SessionKeys> LibertyReachCrypto::x3dh_respond(
    const IdentityKeyPair& local_identity,
    ByteSpan remote_identity_public,
    ByteSpan remote_ephemeral_public) {
  
  // Simplified responder implementation
  // In production, would use stored one-time key
  
  std::vector<std::uint8_t> ikm;
  ikm.insert(ikm.end(), local_identity.pq_secret.begin(), 
             local_identity.pq_secret.begin() + 32);
  ikm.insert(ikm.end(), local_identity.ec_secret.begin(), 
             local_identity.ec_secret.end());
  
  SessionKeys session;
  std::vector<std::uint8_t> okm(140);
  
  std::string info = std::string(protocol_version()) + "-Session-Key";
  hkdf_expand(ikm.data(), ikm.size(),
              reinterpret_cast<const std::uint8_t*>(info.c_str()), info.size(),
              okm.data(), okm.size());
  
  std::memcpy(session.encryption_key.data(), okm.data(), AES256_KEY_SIZE);
  std::memcpy(session.mac_key.data(), okm.data() + 32, AES256_KEY_SIZE);
  std::memcpy(session.nonce.data(), okm.data() + 64, GCM_NONCE_SIZE);
  std::memcpy(session.send_chain_key.data(), okm.data() + 76, 32);
  std::memcpy(session.receive_chain_key.data(), okm.data() + 108, 32);
  
  return session;
}

// ============================================
// MESSAGE ENCRYPTION
// ============================================

Result<ByteArray> LibertyReachCrypto::encrypt_message(
    SessionKeys& session,
    ByteSpan plaintext) {
  
  // AES-256-GCM encryption
  EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
  if (!ctx) {
    return std::unexpected("Failed to create cipher context");
  }
  
  if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                         session.encryption_key.data(),
                         session.nonce.data()) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("EVP_EncryptInit_ex failed");
  }
  
  ByteArray ciphertext(plaintext.size() + GCM_TAG_SIZE);
  int len;
  
  if (EVP_EncryptUpdate(ctx, ciphertext.data(), &len,
                        plaintext.data(), static_cast<int>(plaintext.size())) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("EVP_EncryptUpdate failed");
  }
  
  std::size_t offset = len;
  
  if (EVP_EncryptFinal_ex(ctx, ciphertext.data() + offset, &len) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("EVP_EncryptFinal_ex failed");
  }
  offset += len;
  
  // Get authentication tag
  if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE,
                          ciphertext.data() + offset) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("Failed to get GCM tag");
  }
  
  EVP_CIPHER_CTX_free(ctx);
  
  ciphertext.resize(offset + GCM_TAG_SIZE);
  
  // Update nonce for next message
  for (int i = GCM_NONCE_SIZE - 1; i >= 0; --i) {
    if (++session.nonce[i] != 0) break;
  }
  
  return ciphertext;
}

Result<ByteArray> LibertyReachCrypto::decrypt_message(
    SessionKeys& session,
    ByteSpan ciphertext) {
  
  if (ciphertext.size() < GCM_TAG_SIZE) {
    return std::unexpected("Ciphertext too short");
  }
  
  EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
  if (!ctx) {
    return std::unexpected("Failed to create cipher context");
  }
  
  if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                         session.encryption_key.data(),
                         session.nonce.data()) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("EVP_DecryptInit_ex failed");
  }
  
  // Set expected tag
  const std::uint8_t* tag = ciphertext.data() + ciphertext.size() - GCM_TAG_SIZE;
  if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, GCM_TAG_SIZE,
                          const_cast<std::uint8_t*>(tag)) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("Failed to set GCM tag");
  }
  
  ByteArray plaintext(ciphertext.size() - GCM_TAG_SIZE);
  int len;
  
  if (EVP_DecryptUpdate(ctx, plaintext.data(), &len,
                        ciphertext.data(), 
                        static_cast<int>(ciphertext.size() - GCM_TAG_SIZE)) != 1) {
    EVP_CIPHER_CTX_free(ctx);
    return std::unexpected("EVP_DecryptUpdate failed");
  }
  
  std::size_t offset = len;
  
  int ret = EVP_DecryptFinal_ex(ctx, plaintext.data() + offset, &len);
  EVP_CIPHER_CTX_free(ctx);
  
  if (ret <= 0) {
    return std::unexpected("Authentication failed - invalid ciphertext");
  }
  
  offset += len;
  plaintext.resize(offset);
  
  // Update nonce for next message
  for (int i = GCM_NONCE_SIZE - 1; i >= 0; --i) {
    if (++session.nonce[i] != 0) break;
  }
  
  return plaintext;
}

// ============================================
// STEGANOGRAPHY
// ============================================

Result<ByteArray> LibertyReachCrypto::steganography_encode(
    ByteSpan message,
    ByteSpan cover_image,
    std::size_t width,
    std::size_t height) {
  
  std::size_t capacity = (width * height * 3) / 8;
  if (message.size() > capacity) {
    return std::unexpected("Message too large for cover image");
  }
  
  ByteArray result(cover_image.begin(), cover_image.end());
  
  // Prepare data with length prefix
  std::vector<std::uint8_t> data(4 + message.size());
  std::memcpy(data.data(), &message.size(), 4);
  std::memcpy(data.data() + 4, message.data(), message.size());
  
  // Encode bits into LSB
  std::size_t bit_index = 0;
  std::size_t total_bits = data.size() * 8;
  
  for (std::size_t y = 0; y < height && bit_index < total_bits; ++y) {
    for (std::size_t x = 0; x < width && bit_index < total_bits; ++x) {
      std::size_t pixel_index = (y * width + x) * 3;
      
      for (int c = 0; c < 3 && bit_index < total_bits; ++c) {
        std::size_t byte_index = bit_index / 8;
        int bit_position = 7 - (bit_index % 8);
        std::uint8_t bit = (data[byte_index] >> bit_position) & 1;
        
        result[pixel_index + c] = (result[pixel_index + c] & 0xFE) | bit;
        ++bit_index;
      }
    }
  }
  
  return result;
}

Result<ByteArray> LibertyReachCrypto::steganography_decode(
    ByteSpan stego_image,
    std::size_t width,
    std::size_t height) {
  
  // Extract LSB bits
  std::vector<std::uint8_t> bits;
  bits.reserve(width * height * 3);
  
  for (std::size_t i = 0; i < stego_image.size(); ++i) {
    bits.push_back(stego_image[i] & 1);
  }
  
  // Convert bits to bytes
  std::size_t byte_count = bits.size() / 8;
  std::vector<std::uint8_t> data(byte_count);
  
  for (std::size_t i = 0; i < byte_count; ++i) {
    std::uint8_t byte = 0;
    for (int b = 0; b < 8; ++b) {
      byte |= bits[i * 8 + b] << (7 - b);
    }
    data[i] = byte;
  }
  
  // Read length prefix
  if (data.size() < 4) {
    return std::unexpected("Invalid stego data: too short");
  }
  
  std::size_t msg_len;
  std::memcpy(&msg_len, data.data(), 4);
  
  if (data.size() < 4 + msg_len) {
    return std::unexpected("Invalid stego data: length mismatch");
  }
  
  return ByteArray(data.begin() + 4, data.begin() + 4 + msg_len);
}

std::size_t LibertyReachCrypto::steganography_capacity(
    std::size_t width, std::size_t height) {
  return (width * height * 3) / 8;
}

// ============================================
// PROFILE MANAGEMENT
// ============================================

Result<std::pair<EncryptedProfile, ProfileMasterKey>> 
LibertyReachCrypto::create_profile(
    std::string_view user_id,
    const IdentityKeyPair& identity) {
  
  // Generate master key
  ByteArray master_key(MASTER_KEY_SIZE);
  random_fill(master_key.data(), master_key.size());
  
  // Create recovery hash
  auto recovery_hash = blake3_hash(master_key);
  
  // Split into Shamir shares (3 of 5)
  auto shares_result = split_secret(master_key, 5, 3);
  if (!shares_result) {
    return std::unexpected(shares_result.error());
  }
  
  ProfileMasterKey profile_master;
  std::memcpy(profile_master.key.data(), master_key.data(), MASTER_KEY_SIZE);
  profile_master.created_at = 
      std::chrono::duration_cast<std::chrono::seconds>(
          std::chrono::system_clock::now().time_since_epoch()).count();
  profile_master.recovery_hash = recovery_hash;
  profile_master.recovery_shares = std::move(*shares_result);
  
  // Create encrypted profile
  EncryptedProfile profile;
  profile.user_id = std::string(user_id);
  profile.public_pq_key = {identity.pq_public.begin(), identity.pq_public.end()};
  profile.public_ec_key = {identity.ec_public.begin(), identity.ec_public.end()};
  profile.public_identity_key = {identity.identity_public.begin(), 
                                  identity.identity_public.end()};
  profile.encrypted_data = {};  // Placeholder for actual encrypted data
  profile.recovery_hash = hex_encode(recovery_hash);
  profile.created_at = profile_master.created_at;
  profile.last_seen = profile_master.created_at;
  profile.is_active = true;
  
  return std::make_pair(profile, profile_master);
}

Result<void> LibertyReachCrypto::deactivate_profile(EncryptedProfile& profile) {
  profile.is_active = false;
  return {};
}

Result<void> LibertyReachCrypto::reactivate_profile(EncryptedProfile& profile) {
  profile.is_active = true;
  profile.last_seen = std::chrono::duration_cast<std::chrono::seconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
  return {};
}

// ============================================
// SHAMIR'S SECRET SHARING
// ============================================

Result<std::vector<SecretShare>> LibertyReachCrypto::split_secret(
    ByteSpan key,
    std::size_t total_shares,
    std::size_t threshold) {
  
  if (threshold > total_shares) {
    return std::unexpected("Threshold cannot be greater than total shares");
  }
  if (threshold < 2) {
    return std::unexpected("Threshold must be at least 2");
  }
  
  // Simplified Shamir implementation
  // In production, use proper library over GF(2^8)
  
  std::vector<SecretShare> shares;
  shares.reserve(total_shares);
  
  // Generate random polynomial coefficients
  std::vector<std::vector<std::uint8_t>> coeffs(threshold);
  coeffs[0] = ByteArray(key.begin(), key.end());
  
  for (std::size_t i = 1; i < threshold; ++i) {
    coeffs[i].resize(MASTER_KEY_SIZE);
    random_fill(coeffs[i].data(), coeffs[i].size());
  }
  
  // Evaluate polynomial at points 1, 2, ..., total_shares
  for (std::size_t i = 1; i <= total_shares; ++i) {
    SecretShare share;
    share.id = static_cast<std::uint8_t>(i);
    share.data.resize(MASTER_KEY_SIZE);
    
    for (std::size_t j = 0; j < MASTER_KEY_SIZE; ++j) {
      std::uint8_t result = 0;
      std::uint8_t x_power = 1;
      
      for (std::size_t k = 0; k < threshold; ++k) {
        result = static_cast<std::uint8_t>(
            result + coeffs[k][j] * x_power);
        x_power = static_cast<std::uint8_t>(x_power * i);
      }
      
      share.data[j] = result;
    }
    
    shares.push_back(std::move(share));
  }
  
  return shares;
}

Result<ByteArray> LibertyReachCrypto::recover_secret(
    const std::vector<SecretShare>& shares) {
  
  if (shares.empty()) {
    return std::unexpected("No shares provided");
  }
  
  // Simplified recovery (XOR-based, NOT secure for production)
  // In production, implement Lagrange interpolation over GF(2^8)
  
  ByteArray secret(MASTER_KEY_SIZE, 0);
  
  for (const auto& share : shares) {
    for (std::size_t i = 0; i < MASTER_KEY_SIZE && i < share.data.size(); ++i) {
      secret[i] ^= share.data[i];
    }
  }
  
  return secret;
}

Result<std::vector<SecretShare>> LibertyReachCrypto::refresh_shares(
    const std::vector<SecretShare>& old_shares) {
  
  auto secret = recover_secret(old_shares);
  if (!secret) {
    return std::unexpected(secret.error());
  }
  
  return split_secret(*secret, old_shares.size(), (old_shares.size() / 2) + 1);
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

Result<ByteArray> LibertyReachCrypto::sign(
    const IdentityKeyPair& identity,
    ByteSpan data) {
  
  ByteArray signature(ED25519_SIGNATURE_SIZE);
  std::size_t sig_len;
  
  if (crypto_sign_signature(
          signature.data(), &sig_len,
          data.data(), data.size(),
          identity.identity_secret.data()) != 0) {
    return std::unexpected("Signing failed");
  }
  
  signature.resize(sig_len);
  return signature;
}

Result<bool> LibertyReachCrypto::verify(
    ByteSpan identity_public,
    ByteSpan data,
    ByteSpan signature) {
  
  if (signature.size() != ED25519_SIGNATURE_SIZE) {
    return false;
  }
  
  if (crypto_sign_verify(
          signature.data(), signature.size(),
          data.data(), data.size(),
          identity_public.data()) != 0) {
    return false;
  }
  
  return true;
}

ByteArray LibertyReachCrypto::random_bytes(std::size_t size) {
  ByteArray bytes(size);
  random_fill(bytes.data(), bytes.size());
  return bytes;
}

std::array<std::uint8_t, 32> LibertyReachCrypto::blake3_hash(ByteSpan data) {
  std::array<std::uint8_t, 32> hash;
  ::blake3_hash(data.data(), data.size(), hash.data());
  return hash;
}

}  // namespace liberty_reach
}  // namespace td
