/**
 * Liberty Reach - IPFS Cloud Storage Module
 * Decentralized file storage with IPFS, Filecoin, Arweave
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace storage {

// ============================================
// IPFS CONFIGURATION
// ============================================

/**
 * IPFS Node configuration
 */
struct IPFSConfig {
    std::string node_name;
    std::string api_endpoint;  // Default: http://localhost:5001
    std::string gateway_url;   // Default: https://ipfs.io/ipfs/
    std::vector<std::string> bootstrap_nodes;
    bool enable_pinning = true;
    bool enable_encryption = true;
    int connection_timeout_ms = 30000;
    int max_retries = 3;
};

/**
 * File metadata
 */
struct FileMetadata {
    std::string filename;
    std::string content_type;  // MIME type
    uint64_t file_size = 0;
    std::string created_at;
    std::string modified_at;
    std::string owner_user_id;
    std::string description;
    std::vector<std::string> tags;
    bool is_public = false;
    bool is_encrypted = false;
    std::string encryption_key_hash;
    std::map<std::string, std::string> custom_metadata;
};

/**
 * IPFS File object
 */
struct IPFSFile {
    std::string cid;  // Content Identifier
    std::string ipfs_hash;
    std::string filename;
    uint64_t file_size = 0;
    std::string gateway_url;
    FileMetadata metadata;
    int64_t uploaded_at = 0;
    bool is_pinned = false;
    std::vector<std::string> pin_locations;
};

// ============================================
// STORAGE PROVIDERS
// ============================================

/**
 * Storage provider type
 */
enum class StorageProvider {
    IPFS,           // InterPlanetary File System
    FILECOIN,       // Filecoin (paid storage)
    ARWEAVE,        // Arweave (permanent storage)
    IPFS_PINNING,   // Pinata, Infura, etc.
    HYBRID          // Multiple providers
};

/**
 * Provider configuration
 */
struct ProviderConfig {
    StorageProvider provider;
    std::string api_key;
    std::string api_secret;
    std::string endpoint;
    bool is_primary = true;
    int priority = 0;
};

// ============================================
// PINNING SERVICES
// ============================================

/**
 * Pinning service
 */
struct PinningService {
    std::string name;  // "Pinata", "Infura", "NFT.Storage", "Web3.Storage"
    std::string api_key;
    std::string endpoint;
    bool is_active = false;
    int pinned_files = 0;
    uint64_t storage_used = 0;
    uint64_t storage_limit = 0;
    
    // Pin file
    std::string pinFile(const std::string& file_path, const std::string& name);
    
    // Unpin file
    bool unpinFile(const std::string& cid);
    
    // List pinned files
    std::vector<IPFSFile> listPinnedFiles();
};

// ============================================
// FILE OPERATIONS
// ============================================

/**
 * Upload result
 */
struct UploadResult {
    bool success = false;
    std::string cid;
    std::string ipfs_hash;
    std::string gateway_url;
    std::string provider;
    uint64_t file_size = 0;
    int64_t upload_time_ms = 0;
    std::string error_message;
};

/**
 * Download result
 */
struct DownloadResult {
    bool success = false;
    std::string file_path;
    std::vector<uint8_t> file_data;
    uint64_t file_size = 0;
    int64_t download_time_ms = 0;
    std::string error_message;
};

/**
 * Storage statistics
 */
struct StorageStats {
    uint64_t total_files = 0;
    uint64_t total_size_bytes = 0;
    uint64_t uploaded_bytes = 0;
    uint64_t downloaded_bytes = 0;
    int pinned_files = 0;
    std::map<std::string, int> files_by_provider;
    std::map<std::string, uint64_t> size_by_provider;
};

// ============================================
// ENCRYPTION
// ============================================

/**
 * Encrypted file metadata
 */
struct EncryptedFile {
    std::string original_cid;
    std::string encrypted_cid;
    std::string encryption_algorithm;  // "AES-256-GCM"
    std::string key_hash;
    std::string iv;  // Initialization vector
    std::string auth_tag;
};

// ============================================
// IPFS MANAGER
// ============================================

/**
 * IPFS Manager - Main class
 */
class IPFSManager {
public:
    static IPFSManager& getInstance();

    // ============================================
    // INITIALIZATION
    // ============================================

    /**
     * Initialize IPFS manager
     */
    bool initialize(const IPFSConfig& config = IPFSConfig());

    /**
     * Shutdown IPFS manager
     */
    void shutdown();

    /**
     * Check if IPFS is available
     */
    bool isAvailable() const;

    /**
     * Get IPFS node info
     */
    std::map<std::string, std::string> getNodeInfo();

    // ============================================
    // FILE UPLOAD
    // ============================================

    /**
     * Upload file to IPFS
     */
    UploadResult uploadFile(
        const std::string& file_path,
        const FileMetadata& metadata = FileMetadata());

    /**
     * Upload file data (bytes)
     */
    UploadResult uploadData(
        const std::vector<uint8_t>& data,
        const std::string& filename,
        const std::string& content_type = "application/octet-stream");

    /**
     * Upload file asynchronously
     */
    std::string queueUpload(
        const std::string& file_path,
        std::function<void(const UploadResult&)> callback);

    /**
     * Upload to multiple providers
     */
    std::map<std::string, UploadResult> uploadToMultiple(
        const std::string& file_path,
        const std::vector<StorageProvider>& providers);

    // ============================================
    // FILE DOWNLOAD
    // ============================================

    /**
     * Download file from IPFS
     */
    DownloadResult downloadFile(
        const std::string& cid,
        const std::string& save_path = "");

    /**
     * Download file data
     */
    DownloadResult downloadData(const std::string& cid);

    /**
     * Download via gateway
     */
    DownloadResult downloadViaGateway(
        const std::string& cid,
        const std::string& gateway_url = "");

    // ============================================
    // FILE MANAGEMENT
    // ============================================

    /**
     * Get file info
     */
    IPFSFile getFileInfo(const std::string& cid);

    /**
     * List all files
     */
    std::vector<IPFSFile> listFiles();

    /**
     * List files by user
     */
    std::vector<IPFSFile> listFilesByUser(const std::string& user_id);

    /**
     * Delete file (unpin)
     */
    bool deleteFile(const std::string& cid);

    /**
     * Update file metadata
     */
    bool updateMetadata(const std::string& cid, const FileMetadata& metadata);

    /**
     * Search files
     */
    std::vector<IPFSFile> searchFiles(
        const std::string& query,
        const std::vector<std::string>& tags = {});

    // ============================================
    // PINNING
    // ============================================

    /**
     * Pin file to IPFS
     */
    bool pinFile(const std::string& cid, const std::string& provider = "");

    /**
     * Unpin file
     */
    bool unpinFile(const std::string& cid);

    /**
     * List pinned files
     */
    std::vector<IPFSFile> listPinnedFiles();

    /**
     * Add pinning service
     */
    bool addPinningService(const PinningService& service);

    /**
     * Remove pinning service
     */
    bool removePinningService(const std::string& service_name);

    /**
     * Get pinning services
     */
    std::vector<PinningService> getPinningServices();

    // ============================================
    // STORAGE PROVIDERS
    // ============================================

    /**
     * Add storage provider
     */
    bool addProvider(const ProviderConfig& config);

    /**
     * Remove provider
     */
    bool removeProvider(StorageProvider provider);

    /**
     * Get active providers
     */
    std::vector<ProviderConfig> getProviders();

    /**
     * Set primary provider
     */
    bool setPrimaryProvider(StorageProvider provider);

    // ============================================
    // ENCRYPTION
    // ============================================

    /**
     * Upload encrypted file
     */
    UploadResult uploadEncryptedFile(
        const std::string& file_path,
        const std::string& encryption_key);

    /**
     * Download and decrypt file
     */
    DownloadResult downloadDecryptedFile(
        const std::string& cid,
        const std::string& decryption_key);

    /**
     * Generate encryption key
     */
    std::string generateEncryptionKey();

    // ============================================
    // IPFS SPECIFIC
    // ============================================

    /**
     * Add peer to IPFS network
     */
    bool addPeer(const std::string& peer_id, const std::string& address);

    /**
     * Get peers
     */
    std::vector<std::map<std::string, std::string>> getPeers();

    /**
     * Get network stats
     */
    std::map<std::string, uint64_t> getNetworkStats();

    /**
     * Resolve IPNS name
     */
    std::string resolveIPNS(const std::string& ipns_name);

    /**
     * Publish IPNS name
     */
    std::string publishIPNS(
        const std::string& cid,
        const std::string& key_name);

    // ============================================
    // FILECOIN INTEGRATION
    // ============================================

    /**
     * Store on Filecoin (paid, long-term)
     */
    UploadResult storeOnFilecoin(
        const std::string& cid,
        int64_t duration_days,
        const std::string& wallet_address);

    /**
     * Retrieve from Filecoin
     */
    DownloadResult retrieveFromFilecoin(const std::string& cid);

    /**
     * Check deal status
     */
    std::map<std::string, std::string> getDealStatus(const std::string& deal_id);

    // ============================================
    // ARWEAVE INTEGRATION
    // ============================================

    /**
     * Store on Arweave (permanent)
     */
    UploadResult storeOnArweave(
        const std::string& file_path,
        const std::string& wallet_key);

    /**
     * Get Arweave transaction
     */
    std::map<std::string, std::string> getArweaveTransaction(
        const std::string& tx_id);

    // ============================================
    // STATISTICS
    // ============================================

    /**
     * Get storage statistics
     */
    StorageStats getStatistics();

    /**
     * Get upload speed
     */
    float getUploadSpeed() const;

    /**
     * Get download speed
     */
    float getDownloadSpeed() const;

    // ============================================
    // CACHE
    // ============================================

    /**
     * Enable local cache
     */
    bool enableCache(const std::string& cache_path, uint64_t max_size_bytes);

    /**
     * Clear cache
     */
    bool clearCache();

    /**
     * Get cache size
     */
    uint64_t getCacheSize() const;

private:
    IPFSManager() = default;
    ~IPFSManager() = default;
    IPFSManager(const IPFSManager&) = delete;
    IPFSManager& operator=(const IPFSManager&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;

    IPFSConfig config_;
    std::vector<ProviderConfig> providers_;
    std::vector<PinningService> pinning_services_;
    bool initialized_ = false;

    // Internal methods
    UploadResult uploadToProvider(
        const std::string& file_path,
        StorageProvider provider);
    DownloadResult downloadFromProvider(
        const std::string& cid,
        StorageProvider provider);
    void encryptFile(std::vector<uint8_t>& data, const std::string& key);
    void decryptFile(std::vector<uint8_t>& data, const std::string& key);
};

} // namespace storage
} // namespace liberty_reach
} // namespace td
