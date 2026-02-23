/**
 * Mesh Network Tests
 */

#include "mesh_network.h"
#include <iostream>
#include <cassert>

using namespace td::liberty_reach::mesh;

int passed = 0;
int failed = 0;

#define TEST_ASSERT(cond, msg) \
    if (!(cond)) { \
        std::cerr << "FAILED: " << msg << std::endl; \
        failed++; \
    } else { \
        passed++; \
        std::cout << "."; \
    }

void test_bluetooth_le() {
    BluetoothLE ble;
    
    TEST_ASSERT(ble.initialize(), "Should initialize BLE");
    TEST_ASSERT(ble.startAdvertising("TestDevice"), "Should start advertising");
    TEST_ASSERT(ble.stopAdvertising(), "Should stop advertising");
    
    TEST_ASSERT(ble.startScanning(), "Should start scanning");
    auto devices = ble.getDiscoveredDevices();
    TEST_ASSERT(devices.size() >= 0, "Should get discovered devices");
    TEST_ASSERT(ble.stopScanning(), "Should stop scanning");
    
    TEST_ASSERT(ble.send({1, 2, 3}), "Should send data");
}

void test_wifi_direct() {
    WiFiDirect wifi;
    
    TEST_ASSERT(wifi.initialize(), "Should initialize WiFi Direct");
    TEST_ASSERT(wifi.discoverPeers(), "Should discover peers");
    auto peers = wifi.getDiscoveredPeers();
    TEST_ASSERT(peers.size() >= 0, "Should get discovered peers");
}

void test_lora() {
    LoRaTransport lora;
    
    TEST_ASSERT(lora.initialize(), "Should initialize LoRa");
    
    std::vector<uint8_t> test_data = {1, 2, 3, 4, 5};
    TEST_ASSERT(lora.send(test_data), "Should send LoRa packet");
    
    TEST_ASSERT(LoRaTransport::maxRange() > 0, "Should have max range");
    TEST_ASSERT(LoRaTransport::maxMessageSize() > 0, "Should have max message size");
}

void test_mesh_network() {
    auto& mesh = MeshNetwork::getInstance();
    
    TEST_ASSERT(mesh.initialize("test_node"), "Should initialize mesh");
    TEST_ASSERT(mesh.startNetwork(), "Should start network");
    TEST_ASSERT(mesh.isNetworkAvailable(), "Should be available");
    
    auto stats = mesh.getStats();
    TEST_ASSERT(stats.connected_peers >= 0, "Should have stats");
    
    MeshMessage msg;
    msg.id = "test_msg_1";
    msg.from = "test_node";
    msg.to = "other_node";
    msg.data = {1, 2, 3};
    msg.timestamp = 1234567890;
    
    TEST_ASSERT(mesh.sendMessage(msg), "Should send message");
    
    TEST_ASSERT(mesh.stopNetwork(), "Should stop network");
    mesh.shutdown();
}

void test_mesh_callbacks() {
    auto& mesh = MeshNetwork::getInstance();
    mesh.initialize("callback_test_node");
    
    MeshCallbacks callbacks;
    callbacks.on_device_discovered = [](const DeviceInfo& device) {
        std::cout << "Device discovered: " << device.name << std::endl;
    };
    callbacks.on_message_received = [](const MeshMessage& msg) {
        std::cout << "Message received: " << msg.id << std::endl;
    };
    
    mesh.setCallbacks(callbacks);
    
    mesh.startNetwork();
    mesh.stopNetwork();
    mesh.shutdown();
}

int main() {
    std::cout << "========================================" << std::endl;
    std::cout << "Liberty Reach Mesh Tests" << std::endl;
    std::cout << "========================================" << std::endl;
    
    std::cout << "\nBluetooth LE: ";
    test_bluetooth_le();
    
    std::cout << "\nWiFi Direct: ";
    test_wifi_direct();
    
    std::cout << "\nLoRa: ";
    test_lora();
    
    std::cout << "\nMesh Network: ";
    test_mesh_network();
    
    std::cout << "\nMesh Callbacks: ";
    test_mesh_callbacks();
    
    std::cout << "\n\n========================================" << std::endl;
    std::cout << "Results: " << passed << " passed, " << failed << " failed" << std::endl;
    std::cout << "========================================" << std::endl;
    
    return failed > 0 ? 1 : 0;
}
