/**
 * Liberty Reach Mesh Network Module
 * Bluetooth LE, WiFi Direct, LoRa for offline communication
 */

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace mesh {

/**
 * Transport type
 */
enum class TransportType {
    BluetoothLE,
    WiFiDirect,
    LoRa,
    USB
};

/**
 * Device state
 */
enum class DeviceState {
    Disconnected,
    Connecting,
    Connected,
    Transmitting,
    Error
};

/**
 * Message structure
 */
struct MeshMessage {
    std::string id;
    std::string from;
    std::string to;
    std::vector<uint8_t> data;
    int64_t timestamp;
    uint32_t ttl = 5; // Time to live (hops)
    bool encrypted = true;
};

/**
 * Device info
 */
struct DeviceInfo {
    std::string id;
    std::string name;
    TransportType transport;
    int signal_strength = 0; // RSSI
    DeviceState state = DeviceState::Disconnected;
};

/**
 * Network stats
 */
struct NetworkStats {
    uint32_t messages_sent = 0;
    uint32_t messages_received = 0;
    uint32_t messages_relayed = 0;
    uint32_t bytes_sent = 0;
    uint32_t bytes_received = 0;
    uint32_t connected_peers = 0;
    float avg_latency_ms = 0.0f;
};

/**
 * Callbacks
 */
struct MeshCallbacks {
    std::function<void(const DeviceInfo& device)> on_device_discovered;
    std::function<void(const DeviceInfo& device)> on_device_connected;
    std::function<void(const DeviceInfo& device)> on_device_disconnected;
    std::function<void(const MeshMessage& message)> on_message_received;
    std::function<void(const std::string& error)> on_error;
};

/**
 * Bluetooth LE Transport
 */
class BluetoothLE {
public:
    BluetoothLE();
    ~BluetoothLE();

    /**
     * Initialize Bluetooth LE
     */
    bool initialize();

    /**
     * Start advertising
     */
    bool startAdvertising(const std::string& device_name);

    /**
     * Stop advertising
     */
    bool stopAdvertising();

    /**
     * Start scanning
     */
    bool startScanning();

    /**
     * Stop scanning
     */
    bool stopScanning();

    /**
     * Connect to device
     */
    bool connect(const std::string& device_address);

    /**
     * Disconnect
     */
    bool disconnect();

    /**
     * Send data
     */
    bool send(const std::vector<uint8_t>& data);

    /**
     * Get discovered devices
     */
    std::vector<DeviceInfo> getDiscoveredDevices() const;

    /**
     * Check if Bluetooth is available
     */
    static bool isAvailable();

    /**
     * Get max message size
     */
    static constexpr size_t maxMessageSize() { return 512; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * WiFi Direct Transport
 */
class WiFiDirect {
public:
    WiFiDirect();
    ~WiFiDirect();

    /**
     * Initialize WiFi Direct
     */
    bool initialize();

    /**
     * Create group (become group owner)
     */
    bool createGroup();

    /**
     * Remove group
     */
    bool removeGroup();

    /**
     * Discover peers
     */
    bool discoverPeers();

    /**
     * Connect to peer
     */
    bool connect(const std::string& peer_address);

    /**
     * Disconnect
     */
    bool disconnect();

    /**
     * Send data
     */
    bool send(const std::vector<uint8_t>& data);

    /**
     * Get discovered peers
     */
    std::vector<DeviceInfo> getDiscoveredPeers() const;

    /**
     * Check if WiFi Direct is available
     */
    static bool isAvailable();

    /**
     * Get max message size
     */
    static constexpr size_t maxMessageSize() { return 65536; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * LoRa Transport (long range, low power)
 */
class LoRaTransport {
public:
    LoRaTransport();
    ~LoRaTransport();

    /**
     * Initialize LoRa
     */
    bool initialize(
        double frequency = 868.0, // MHz (EU)
        uint32_t bandwidth = 125000, // Hz
        uint8_t spreading_factor = 7,
        uint8_t coding_rate = 5);

    /**
     * Send packet
     */
    bool send(const std::vector<uint8_t>& data);

    /**
     * Receive packet
     */
    std::vector<uint8_t> receive(int timeout_ms = 1000);

    /**
     * Get signal strength
     */
    int getSignalStrength() const;

    /**
     * Get SNR
     */
    float getSNR() const;

    /**
     * Check if LoRa is available
     */
    static bool isAvailable();

    /**
     * Get max range (meters)
     */
    static constexpr int maxRange() { return 10000; } // 10km urban, 50km rural

    /**
     * Get max message size
     */
    static constexpr size_t maxMessageSize() { return 240; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * Mesh Network Manager
 */
class MeshNetwork {
public:
    static MeshNetwork& getInstance();

    /**
     * Initialize mesh network
     */
    bool initialize(const std::string& node_id);

    /**
     * Shutdown mesh network
     */
    void shutdown();

    /**
     * Enable transport
     */
    bool enableTransport(TransportType type);

    /**
     * Disable transport
     */
    bool disableTransport(TransportType type);

    /**
     * Start network
     */
    bool startNetwork();

    /**
     * Stop network
     */
    bool stopNetwork();

    /**
     * Send message
     */
    bool sendMessage(const MeshMessage& message);

    /**
     * Broadcast message to all connected peers
     */
    bool broadcastMessage(const MeshMessage& message);

    /**
     * Get connected devices
     */
    std::vector<DeviceInfo> getConnectedDevices() const;

    /**
     * Get network stats
     */
    NetworkStats getStats() const;

    /**
     * Set callbacks
     */
    void setCallbacks(const MeshCallbacks& callbacks);

    /**
     * Get node ID
     */
    std::string getNodeId() const;

    /**
     * Check if network is available
     */
    bool isNetworkAvailable() const;

    /**
     * Get Bluetooth LE transport
     */
    BluetoothLE& getBluetoothLE();

    /**
     * Get WiFi Direct transport
     */
    WiFiDirect& getWiFiDirect();

    /**
     * Get LoRa transport
     */
    LoRaTransport& getLoRa();

private:
    MeshNetwork();
    ~MeshNetwork();
    MeshNetwork(const MeshNetwork&) = delete;
    MeshNetwork& operator=(const MeshNetwork&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace mesh
} // namespace liberty_reach
} // namespace td
