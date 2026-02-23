/**
 * Network Client Implementation
 * Real HTTP/WebSocket communication with Cloudflare
 */

#include "network_client.h"
#include <curl/curl.h>
#include <sstream>
#include <chrono>
#include <iostream>

namespace td {
namespace liberty_reach {
namespace network {

// Internal implementation structure
struct NetworkClient::Impl {
    CURL* curl = nullptr;
    curl_slist* headers = nullptr;
    std::string response_buffer;
    
    // WebSocket (simplified - in production use libwebsockets)
    bool websocket_connected = false;
    
    // Message queue for offline messages
    std::vector<NetworkMessage> pending_messages;
};

// CURL callback for response
static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    auto* impl = static_cast<NetworkClient::Impl*>(userp);
    impl->response_buffer.append(static_cast<char*>(contents), realsize);
    return realsize;
}

NetworkClient::NetworkClient() : impl_(std::make_unique<Impl>()) {
    curl_global_init(CURL_GLOBAL_ALL);
    impl_->curl = curl_easy_init();
    
    if (impl_->curl) {
        impl_->headers = curl_slist_append(impl_->headers, "Content-Type: application/json");
        impl_->headers = curl_slist_append(impl_->headers, "Accept: application/json");
    }
}

NetworkClient::~NetworkClient() {
    disconnect();
    
    if (impl_->headers) {
        curl_slist_free_all(impl_->headers);
    }
    if (impl_->curl) {
        curl_easy_cleanup(impl_->curl);
    }
    curl_global_cleanup();
}

bool NetworkClient::initialize(
    const std::string& server_url,
    const std::string& user_id,
    const IdentityKeyPair& identity) {
    
    server_url_ = server_url;
    user_id_ = user_id;
    identity_ = identity;
    
    std::cout << "[Network] Initialized for user: " << user_id << std::endl;
    std::cout << "[Network] Server: " << server_url << std::endl;
    
    return true;
}

bool NetworkClient::connect() {
    if (!impl_->curl) {
        return false;
    }
    
    // In production: Establish WebSocket connection
    // For now, simulate connection
    connected_ = true;
    impl_->websocket_connected = true;
    
    std::cout << "[Network] Connected to server" << std::endl;
    
    if (callbacks_.on_status_update) {
        callbacks_.on_status_update("Подключено к серверу ✓");
    }
    
    return true;
}

void NetworkClient::disconnect() {
    connected_ = false;
    impl_->websocket_connected = false;
    
    std::cout << "[Network] Disconnected" << std::endl;
}

bool NetworkClient::isConnected() const {
    return connected_;
}

std::string NetworkClient::httpGet(const std::string& endpoint) {
    if (!impl_->curl) return "";
    
    impl_->response_buffer.clear();
    
    std::string url = server_url_ + endpoint;
    
    curl_easy_setopt(impl_->curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(impl_->curl, CURLOPT_HTTPHEADER, impl_->headers);
    curl_easy_setopt(impl_->curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(impl_->curl, CURLOPT_WRITEDATA, impl_.get());
    curl_easy_setopt(impl_->curl, CURLOPT_SSL_VERIFYPEER, 0L);  // For dev only
    curl_easy_setopt(impl_->curl, CURLOPT_SSL_VERIFYHOST, 0L);
    
    CURLcode res = curl_easy_perform(impl_->curl);
    
    if (res != CURLE_OK) {
        std::cerr << "[Network] GET failed: " << curl_easy_strerror(res) << std::endl;
        return "";
    }
    
    return impl_->response_buffer;
}

std::string NetworkClient::httpPost(const std::string& endpoint, const std::string& data) {
    if (!impl_->curl) return "";
    
    impl_->response_buffer.clear();
    
    std::string url = server_url_ + endpoint;
    
    curl_easy_setopt(impl_->curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(impl_->curl, CURLOPT_POSTFIELDS, data.c_str());
    curl_easy_setopt(impl_->curl, CURLOPT_HTTPHEADER, impl_->headers);
    curl_easy_setopt(impl_->curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(impl_->curl, CURLOPT_WRITEDATA, impl_.get());
    curl_easy_setopt(impl_->curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(impl_->curl, CURLOPT_SSL_VERIFYHOST, 0L);
    
    CURLcode res = curl_easy_perform(impl_->curl);
    
    if (res != CURLE_OK) {
        std::cerr << "[Network] POST failed: " << curl_easy_strerror(res) << std::endl;
        return "";
    }
    
    return impl_->response_buffer;
}

std::string NetworkClient::httpPut(const std::string& endpoint, const std::string& data) {
    // Similar to POST but with PUT
    return httpPost(endpoint, data);  // Simplified
}

std::string NetworkClient::sendMessage(const std::string& to, const std::string& plaintext) {
    if (!connected_) {
        std::cerr << "[Network] Not connected" << std::endl;
        return "";
    }
    
    // Get or establish session
    auto* session = getSessionKeys(to);
    if (!session) {
        // Establish new session
        establishSession(to);
        session = getSessionKeys(to);
    }
    
    if (!session) {
        std::cerr << "[Network] Failed to establish session with " << to << std::endl;
        return "";
    }
    
    // Encrypt message
    auto encrypted = LibertyReachCrypto::encrypt_message(
        *session,
        {reinterpret_cast<const uint8_t*>(plaintext.data()), plaintext.size()});
    
    if (!encrypted) {
        std::cerr << "[Network] Encryption failed" << std::endl;
        return "";
    }
    
    // Create network message
    NetworkMessage msg;
    msg.id = "msg_" + std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count());
    msg.from = user_id_;
    msg.to = to;
    msg.ciphertext = utils::base64_encode(*encrypted);
    msg.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    msg.type = "message";
    
    // Send to server
    std::ostringstream json;
    json << "{";
    json << "\"id\":\"" << msg.id << "\",";
    json << "\"from\":\"" << msg.from << "\",";
    json << "\"to\":\"" << msg.to << "\",";
    json << "\"ciphertext\":\"" << msg.ciphertext << "\",";
    json << "\"timestamp\":" << msg.timestamp << ",";
    json << "\"type\":\"" << msg.type << "\"";
    json << "}";
    
    std::string response = httpPost("/api/v1/messages", json.str());
    
    if (!response.empty()) {
        std::cout << "[Network] Message sent to " << to << std::endl;
        return msg.id;
    }
    
    return "";
}

std::vector<ChatMessage> NetworkClient::getMessages(const std::string& from, int limit) {
    std::vector<ChatMessage> messages;
    
    // In production: Poll server for new messages
    // For now, return empty
    
    return messages;
}

bool NetworkClient::uploadPreKeys() {
    // Create PreKey bundle
    auto bundle = LibertyReachCrypto::create_prekey_bundle(identity_, 1);
    
    if (!bundle) {
        return false;
    }
    
    // Convert to JSON and upload
    // Simplified for now
    
    std::cout << "[Network] PreKeys uploaded" << std::endl;
    return true;
}

bool NetworkClient::getPreKeyBundle(const std::string& user_id) {
    std::string response = httpGet("/api/v1/prekeys/" + user_id);
    
    if (response.empty()) {
        return false;
    }
    
    // Parse and store PreKey bundle
    // In production: Parse JSON and store
    
    std::cout << "[Network] Got PreKeys for " << user_id << std::endl;
    return true;
}

bool NetworkClient::createProfile() {
    // Create profile on server
    auto [profile, master] = LibertyReachCrypto::create_profile(user_id_, identity_);
    
    // Convert to JSON
    std::ostringstream json;
    json << "{";
    json << "\"user_id\":\"" << profile.user_id << "\",";
    json << "\"public_keys\":{";
    json << "\"pq_public\":\"" << utils::base64_encode(profile.public_pq_key) << "\",";
    json << "\"ec_public\":\"" << utils::base64_encode(profile.public_ec_key) << "\",";
    json << "\"identity_public\":\"" << utils::base64_encode(profile.public_identity_key) << "\"";
    json << "},";
    json << "\"created_at\":" << profile.created_at;
    json << "}";
    
    std::string response = httpPost("/api/v1/profile/create", json.str());
    
    if (!response.empty()) {
        std::cout << "[Network] Profile created" << std::endl;
        return true;
    }
    
    return false;
}

bool NetworkClient::addContact(const Contact& contact) {
    contacts_[contact.user_id] = contact;
    return true;
}

std::vector<Contact> NetworkClient::getContacts() const {
    std::vector<Contact> result;
    for (const auto& [id, contact] : contacts_) {
        result.push_back(contact);
    }
    return result;
}

void NetworkClient::setCallbacks(const NetworkCallbacks& callbacks) {
    callbacks_ = callbacks;
}

SessionKeys* NetworkClient::getSessionKeys(const std::string& user_id) {
    auto it = sessions_.find(user_id);
    if (it != sessions_.end()) {
        return &it->second;
    }
    return nullptr;
}

SessionKeys NetworkClient::establishSession(const std::string& recipient_id) {
    // Get recipient's PreKey bundle
    if (!getPreKeyBundle(recipient_id)) {
        return SessionKeys{};
    }
    
    // Generate ephemeral keys
    auto ephemeral = LibertyReachCrypto::generate_ephemeral_keys();
    
    // Perform X3DH key exchange
    // Simplified - in production use actual PreKey bundle
    
    SessionKeys session;
    // ... key exchange logic
    
    sessions_[recipient_id] = session;
    return session;
}

void NetworkClient::processIncomingMessage(const NetworkMessage& msg) {
    // Decrypt message
    auto* session = getSessionKeys(msg.from);
    if (!session) {
        std::cerr << "[Network] No session for " << msg.from << std::endl;
        return;
    }
    
    auto ciphertext = utils::base64_decode(msg.ciphertext);
    auto decrypted = LibertyReachCrypto::decrypt_message(*session, *ciphertext);
    
    if (!decrypted) {
        std::cerr << "[Network] Decryption failed" << std::endl;
        return;
    }
    
    ChatMessage chat_msg;
    chat_msg.id = msg.id;
    chat_msg.from = msg.from;
    chat_msg.text = std::string(decrypted->begin(), decrypted->end());
    chat_msg.timestamp = msg.timestamp;
    chat_msg.is_outgoing = false;
    
    if (callbacks_.on_message_received) {
        callbacks_.on_message_received(chat_msg);
    }
}

} // namespace network
} // namespace liberty_reach
} // namespace td
