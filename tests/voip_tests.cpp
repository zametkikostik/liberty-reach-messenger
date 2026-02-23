/**
 * VoIP Module Tests
 */

#include "voip_manager.h"
#include <iostream>
#include <cassert>

using namespace td::liberty_reach::voip;

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

void test_zrtp_context() {
    ZRTPContext ctx;
    
    TEST_ASSERT(ctx.initialize(), "Should initialize ZRTP");
    TEST_ASSERT(!ctx.getSAS().empty(), "Should have SAS");
    TEST_ASSERT(!ctx.getCipherSuite().empty(), "Should have cipher suite");
    
    std::vector<uint8_t> test_data = {1, 2, 3, 4, 5};
    auto protected_data = ctx.protectRTP(test_data);
    auto unprotected = ctx.unprotectRTP(protected_data);
    
    TEST_ASSERT(protected_data.size() > 0, "Should protect RTP");
}

void test_audio_device() {
    AudioDevice audio;
    
    TEST_ASSERT(audio.initialize(), "Should initialize audio");
    TEST_ASSERT(audio.startRecording(), "Should start recording");
    TEST_ASSERT(audio.stopRecording(), "Should stop recording");
    TEST_ASSERT(audio.startPlayout(), "Should start playout");
    TEST_ASSERT(audio.stopPlayout(), "Should stop playout");
    
    auto devices = AudioDevice::getRecordingDevices();
    TEST_ASSERT(!devices.empty(), "Should have recording devices");
    
    auto playout = AudioDevice::getPlayoutDevices();
    TEST_ASSERT(!playout.empty(), "Should have playout devices");
}

void test_video_device() {
    VideoDevice video;
    
    TEST_ASSERT(video.initialize(), "Should initialize video");
    
    auto devices = VideoDevice::getCaptureDevices();
    TEST_ASSERT(!devices.empty(), "Should have capture devices");
}

void test_peer_connection() {
    PeerConnection pc;
    
    CallConfig config;
    config.media_type = MediaType::AudioOnly;
    
    TEST_ASSERT(pc.initialize(config), "Should initialize peer connection");
    TEST_ASSERT(pc.getState() == CallState::Idle, "Should be idle");
    
    CallCallbacks callbacks;
    callbacks.on_state_changed = [](CallState state) {
        std::cout << "State changed: " << static_cast<int>(state) << std::endl;
    };
    pc.setCallbacks(callbacks);
    
    TEST_ASSERT(pc.createOffer(), "Should create offer");
    TEST_ASSERT(pc.getState() == CallState::WaitingForAnswer, "Should wait for answer");
    
    TEST_ASSERT(pc.endCall(), "Should end call");
    TEST_ASSERT(pc.getState() == CallState::Ended, "Should be ended");
}

void test_voip_manager() {
    auto& voip = VoIPManager::getInstance();
    
    TEST_ASSERT(voip.initialize(), "Should initialize VoIP manager");
    TEST_ASSERT(voip.canMakeCall(), "Should be able to make calls");
    
    auto turn_servers = VoIPManager::fetchTurnServers("test_endpoint");
    TEST_ASSERT(!turn_servers.empty(), "Should have TURN servers");
    
    voip.shutdown();
}

int main() {
    std::cout << "========================================" << std::endl;
    std::cout << "Liberty Reach VoIP Tests" << std::endl;
    std::cout << "========================================" << std::endl;
    
    std::cout << "\nZRTP Context: ";
    test_zrtp_context();
    
    std::cout << "\nAudio Device: ";
    test_audio_device();
    
    std::cout << "\nVideo Device: ";
    test_video_device();
    
    std::cout << "\nPeer Connection: ";
    test_peer_connection();
    
    std::cout << "\nVoIP Manager: ";
    test_voip_manager();
    
    std::cout << "\n\n========================================" << std::endl;
    std::cout << "Results: " << passed << " passed, " << failed << " failed" << std::endl;
    std::cout << "========================================" << std::endl;
    
    return failed > 0 ? 1 : 0;
}
