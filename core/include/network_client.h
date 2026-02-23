/**
 * Liberty Reach Network Client
 * Real network communication with Cloudflare backend
 */

#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <map>

#include "liberty_reach_crypto.h"

namespace td {
namespace liberty_reach {
namespace network {

/**
 * Message structure for network transmission
 */
struct NetworkMessage {
    std::string id;
    std::string from;
    std::string to;
    std::string ciphertext;  // Base64 encoded
    int64_t timestamp;
    std::string type;  // "message", "signal", "file"
    std::map<std::string, std::string> metadata;
};

/**
 * Contact structure
 */
struct Contact {
    std::string user_id;
    std::string display_name;
    std::string public_key;  // Base64 encoded identity public key
    bool is_online = false;
    int64_t last_seen = 0;
};

/**
 * Chat message (decrypted)
 */
struct ChatMessage {
    std::string id;
    std::string from;
    std::string text;  // Decrypted text
    int64_t timestamp;
    bool is_outgoing = false;
    bool is_encrypted = true;
};

/**
 * Network callbacks
 */
struct NetworkCallbacks {
    std::function<void(const ChatMessage& msg)> on_message_received;
    std::function<void(const std::string& user_id, bool online)> on_user_status;
    std::function<void(const std::string& error)> on_error;
    std::function<void(const std::string& status)> on_status_update;
};

/**
 * Network Client - Main class for server communication
 */
class NetworkClient {
public:
    NetworkClient();
    ~NetworkClient();

    /**
     * Initialize network client
     * @param server_url Cloudflare Worker URL
     * @param user_id Local user ID
     * @param identity Local identity keys
     */
    bool initialize(
        const std::string& server_url,
        const std::string& user_id,
        const IdentityKeyPair& identity);

    /**
     * Connect to server (WebSocket)
     */
    bool connect();

    /**
     * Disconnect from server
     */
    void disconnect();

    /**
     * Check if connected
     */
    bool isConnected() const;

    /**
     * Send message to user
     * @param to Recipient user ID
     * @param plaintext Message text
     * @return Message ID if sent
     */
    std::string sendMessage(const std::string& to, const std::string& plaintext);

    /**
     * Get messages for user (polling)
     */
    std::vector<ChatMessage> getMessages(const std::string& from, int limit = 50);

    /**
     * Upload PreKey bundle
     */
    bool uploadPreKeys();

    /**
     * Get recipient's PreKey bundle
     */
    bool getPreKeyBundle(const std::string& user_id);

    /**
     * Create profile on server
     */
    bool createProfile();

    /**
     * Get profile info
     */
    bool getProfile(const std::string& user_id);

    /**
     * Add contact
     */
    bool addContact(const Contact& contact);

    /**
     * Get contacts
     */
    std::vector<Contact> getContacts() const;

    /**
     * Set callbacks
     */
    void setCallbacks(const NetworkCallbacks& callbacks);

    /**
     * Get session keys for user
     */
    SessionKeys* getSessionKeys(const std::string& user_id);

    /**
     * Get user ID
     */
    std::string getUserId() const { return user_id_; }

    /**
     * Get server URL
     */
    std::string getServerUrl() const { return server_url_; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;

    std::string server_url_;
    std::string user_id_;
    IdentityKeyPair identity_;
    bool connected_ = false;

    // Sessions with other users
    std::map<std::string, SessionKeys> sessions_;
    std::map<std::string, Contact> contacts_;

    NetworkCallbacks callbacks_;

    // Internal methods
    std::string httpGet(const std::string& endpoint);
    std::string httpPost(const std::string& endpoint, const std::string& data);
    std::string httpPut(const std::string& endpoint, const std::string& data);

    void processIncomingMessage(const NetworkMessage& msg);
    SessionKeys establishSession(const std::string& recipient_id);
};

} // namespace network
} // namespace liberty_reach
} // namespace td
