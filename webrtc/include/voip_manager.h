/**
 * Liberty Reach VoIP Module
 * WebRTC + ZRTP for encrypted voice/video calls
 */

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace voip {

// Forward declarations
class PeerConnection;
class ZRTPContext;
class AudioDevice;
class VideoDevice;

/**
 * Call state
 */
enum class CallState {
    Idle,
    CreatingOffer,
    WaitingForAnswer,
    Connected,
    Reconnecting,
    Ended,
    Error
};

/**
 * Media type
 */
enum class MediaType {
    AudioOnly,
    VideoOnly,
    AudioVideo
};

/**
 * Call statistics
 */
struct CallStats {
    uint64_t duration_ms = 0;
    uint32_t packets_sent = 0;
    uint32_t packets_received = 0;
    uint32_t bytes_sent = 0;
    uint32_t bytes_received = 0;
    float jitter_ms = 0.0f;
    float packet_loss_percent = 0.0f;
    float round_trip_time_ms = 0.0f;
};

/**
 * ICE server configuration
 */
struct ICEServer {
    std::string url;
    std::string username;
    std::string credential;
};

/**
 * Call configuration
 */
struct CallConfig {
    MediaType media_type = MediaType::AudioVideo;
    std::vector<ICEServer> ice_servers;
    bool enable_encryption = true;
    bool enable_noise_suppression = true;
    bool enable_echo_cancellation = true;
    int audio_bitrate_kbps = 64;
    int video_bitrate_kbps = 500;
    int max_video_resolution_width = 1280;
    int max_video_resolution_height = 720;
};

/**
 * Callbacks for call events
 */
struct CallCallbacks {
    std::function<void(CallState state)> on_state_changed;
    std::function<void(const std::string& local_sdp)> on_local_sdp;
    std::function<void(const std::string& ice_candidate)> on_ice_candidate;
    std::function<void(const CallStats& stats)> on_stats_update;
    std::function<void(const std::string& error)> on_error;
};

/**
 * ZRTP Context for media encryption
 */
class ZRTPContext {
public:
    ZRTPContext();
    ~ZRTPContext();

    /**
     * Initialize ZRTP
     */
    bool initialize();

    /**
     * Process outgoing RTP packet
     */
    std::vector<uint8_t> protectRTP(const std::vector<uint8_t>& rtp_packet);

    /**
     * Process incoming SRTP packet
     */
    std::vector<uint8_t> unprotectRTP(const std::vector<uint8_t>& srtp_packet);

    /**
     * Get SAS (Short Authentication String) for verification
     */
    std::string getSAS() const;

    /**
     * Check if SAS is verified
     */
    bool isSASVerified() const;

    /**
     * Mark SAS as verified
     */
    void setSASVerified(bool verified);

    /**
     * Get cipher suite name
     */
    std::string getCipherSuite() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * Audio Device Manager
 */
class AudioDevice {
public:
    AudioDevice();
    ~AudioDevice();

    /**
     * Initialize audio device
     */
    bool initialize();

    /**
     * Start recording
     */
    bool startRecording();

    /**
     * Stop recording
     */
    bool stopRecording();

    /**
     * Start playout
     */
    bool startPlayout();

    /**
     * Stop playout
     */
    bool stopPlayout();

    /**
     * Get available recording devices
     */
    static std::vector<std::string> getRecordingDevices();

    /**
     * Get available playout devices
     */
    static std::vector<std::string> getPlayoutDevices();

    /**
     * Set recording device
     */
    bool setRecordingDevice(int index);

    /**
     * Set playout device
     */
    bool setPlayoutDevice(int index);

    /**
     * Enable noise suppression
     */
    void setNoiseSuppression(bool enabled);

    /**
     * Enable echo cancellation
     */
    void setEchoCancellation(bool enabled);

    /**
     * Set recording volume
     */
    bool setRecordingVolume(int volume);

    /**
     * Set playout volume
     */
    bool setPlayoutVolume(int volume);

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * Video Device Manager
 */
class VideoDevice {
public:
    VideoDevice();
    ~VideoDevice();

    /**
     * Initialize video device
     */
    bool initialize();

    /**
     * Start capture
     */
    bool startCapture(int width, int height, int fps);

    /**
     * Stop capture
     */
    bool stopCapture();

    /**
     * Get available capture devices
     */
    static std::vector<std::string> getCaptureDevices();

    /**
     * Set capture device
     */
    bool setCaptureDevice(int index);

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * Main Peer Connection class
 */
class PeerConnection {
public:
    PeerConnection();
    ~PeerConnection();

    /**
     * Initialize peer connection
     */
    bool initialize(const CallConfig& config);

    /**
     * Create SDP offer
     */
    bool createOffer();

    /**
     * Set local SDP
     */
    bool setLocalSDP(const std::string& sdp);

    /**
     * Set remote SDP
     */
    bool setRemoteSDP(const std::string& sdp);

    /**
     * Add ICE candidate
     */
    bool addICECandidate(const std::string& candidate);

    /**
     * Get local SDP
     */
    std::string getLocalSDP() const;

    /**
     * Get call state
     */
    CallState getState() const;

    /**
     * Get call statistics
     */
    CallStats getStats() const;

    /**
     * Set callbacks
     */
    void setCallbacks(const CallCallbacks& callbacks);

    /**
     * Start call
     */
    bool startCall();

    /**
     * Answer call
     */
    bool answerCall();

    /**
     * End call
     */
    bool endCall();

    /**
     * Hold call
     */
    bool holdCall();

    /**
     * Resume call
     */
    bool resumeCall();

    /**
     * Mute microphone
     */
    bool muteMicrophone(bool muted);

    /**
     * Is microphone muted
     */
    bool isMicrophoneMuted() const;

    /**
     * Switch camera
     */
    bool switchCamera();

    /**
     * Get ZRTP context
     */
    ZRTPContext& getZRTPContext();

    /**
     * Get audio device
     */
    AudioDevice& getAudioDevice();

    /**
     * Get video device
     */
    VideoDevice& getVideoDevice();

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * VoIP Manager - Main interface
 */
class VoIPManager {
public:
    static VoIPManager& getInstance();

    /**
     * Initialize VoIP system
     */
    bool initialize();

    /**
     * Shutdown VoIP system
     */
    void shutdown();

    /**
     * Create outgoing call
     */
    std::shared_ptr<PeerConnection> createCall(
        const std::string& callee_id,
        const CallConfig& config = CallConfig());

    /**
     * Answer incoming call
     */
    std::shared_ptr<PeerConnection> answerCall(
        const std::string& call_id,
        const CallConfig& config = CallConfig());

    /**
     * Get active call
     */
    std::shared_ptr<PeerConnection> getActiveCall() const;

    /**
     * Get all active calls
     */
    std::vector<std::shared_ptr<PeerConnection>> getAllActiveCalls() const;

    /**
     * Check if call is possible
     */
    bool canMakeCall() const;

    /**
     * Get TURN servers from Cloudflare
     */
    static std::vector<ICEServer> fetchTurnServers(
        const std::string& turn_endpoint);

private:
    VoIPManager();
    ~VoIPManager();
    VoIPManager(const VoIPManager&) = delete;
    VoIPManager& operator=(const VoIPManager&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace voip
} // namespace liberty_reach
} // namespace td
