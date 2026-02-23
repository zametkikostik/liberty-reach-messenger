/**
 * Liberty Reach - Auto Translation Module
 * Real-time translation for messages, audio, video with subtitles
 * Supports 100+ languages including Bulgarian
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <queue>
#include <mutex>
#include <thread>

namespace td {
namespace liberty_reach {
namespace translation {

// ============================================
// LANGUAGE SUPPORT
// ============================================

/**
 * Supported languages (100+)
 */
enum class Language {
    // European
    BULGARIAN,      // 🇧🇬 Bulgarian (Priority!)
    ENGLISH,        // 🇬🇧 English
    RUSSIAN,        // 🇷🇺 Russian
    GERMAN,         // 🇩🇪 German
    FRENCH,         // 🇫🇷 French
    SPANISH,        // 🇪🇸 Spanish
    ITALIAN,        // 🇮🇹 Italian
    PORTUGUESE,     // 🇵🇹 Portuguese
    DUTCH,          // 🇳🇱 Dutch
    POLISH,         // 🇵🇱 Polish
    UKRAINIAN,      // 🇺🇦 Ukrainian
    CZECH,          // 🇨🇿 Czech
    SLOVAK,         // 🇸🇰 Slovak
    ROMANIAN,       // 🇷🇴 Romanian
    HUNGARIAN,      // 🇭🇺 Hungarian
    GREEK,          // 🇬🇷 Greek
    TURKISH,        // 🇹🇷 Turkish
    SWEDISH,        // 🇸🇪 Swedish
    NORWEGIAN,      // 🇳🇴 Norwegian
    DANISH,         // 🇩🇰 Danish
    FINNISH,        // 🇫🇮 Finnish
    
    // Asian
    CHINESE_SIMP,   // 🇨🇳 Chinese (Simplified)
    CHINESE_TRAD,   // 🇹🇼 Chinese (Traditional)
    JAPANESE,       // 🇯🇵 Japanese
    KOREAN,         // 🇰🇷 Korean
    HINDI,          // 🇮🇳 Hindi
    THAI,           // 🇹🇭 Thai
    VIETNAMESE,     // 🇻🇳 Vietnamese
    INDONESIAN,     // 🇮🇩 Indonesian
    MALAY,          // 🇲🇾 Malay
    TAGALOG,        // 🇵🇭 Tagalog
    
    // Middle Eastern
    ARABIC,         // 🇸🇦 Arabic
    HEBREW,         // 🇮🇱 Hebrew
    PERSIAN,        // 🇮🇷 Persian (Farsi)
    URDU,           // 🇵🇰 Urdu
    
    // African
    SWAHILI,        // 🇰🇪 Swahili
    AFRIKAANS,      // 🇿🇦 Afrikaans
    ZULU,           // 🇿🇦 Zulu
    
    // Other
    AUTO_DETECT     // 🔍 Auto-detect language
};

/**
 * Language info
 */
struct LanguageInfo {
    Language code;
    std::string name;
    std::string native_name;
    std::string flag_emoji;
    std::string iso_code;  // ISO 639-1
    bool supports_text = true;
    bool supports_audio = true;
    bool supports_video = true;
};

// ============================================
// TRANSLATION TYPES
// ============================================

/**
 * Translation quality
 */
enum class TranslationQuality {
    FAST,      // Fast, lower quality
    BALANCED,  // Balanced
    HIGH,      // High quality, slower
    NEURAL     // Neural MT (best quality)
};

/**
 * Text translation result
 */
struct TextTranslation {
    std::string original_text;
    std::string translated_text;
    Language source_language;
    Language target_language;
    float confidence = 0.0f;
    std::string detected_language;
    int64_t translation_time_ms = 0;
    bool is_auto_detected = false;
    std::vector<std::string> alternative_translations;
};

/**
 * Audio translation result
 */
struct AudioTranslation {
    std::string audio_url;
    std::string original_audio_url;
    std::string transcribed_text;
    std::string translated_text;
    std::string translated_audio_url;  // TTS output
    Language source_language;
    Language target_language;
    float audio_duration_seconds = 0.0f;
    int64_t processing_time_ms = 0;
    bool is_streaming = false;
};

/**
 * Video translation result
 */
struct VideoTranslation {
    std::string video_url;
    std::string original_video_url;
    std::string translated_video_url;
    std::vector<Subtitle> subtitles;
    Language source_language;
    Language target_language;
    float video_duration_seconds = 0.0f;
    int64_t processing_time_ms = 0;
    bool has_voice_over = false;
    bool preserve_original_audio = false;
};

/**
 * Subtitle entry
 */
struct Subtitle {
    int64_t start_ms = 0;
    int64_t end_ms = 0;
    std::string text;
    std::string original_text;
    Language language;
    int line_number = 0;
};

// ============================================
// TRANSLATION SETTINGS
// ============================================

/**
 * Translation settings
 */
struct TranslationSettings {
    Language target_language = Language::BULGARIAN;  // Default to Bulgarian
    TranslationQuality quality = TranslationQuality::BALANCED;
    bool auto_detect_source = true;
    bool show_original = true;
    bool show_translation = true;
    bool enable_tts = true;  // Text-to-speech
    bool preserve_formatting = true;
    bool translate_emoji = true;
    bool translate_links = false;
    bool translate_hashtags = false;
    float speech_rate = 1.0f;
    float speech_pitch = 1.0f;
    std::string tts_voice = "default";
    bool enable_subtitles = true;
    std::string subtitle_style = "default";
    std::string subtitle_position = "bottom";
    float subtitle_size = 1.0f;
};

/**
 * Translation queue item
 */
struct TranslationTask {
    std::string id;
    std::string content;  // Text, audio URL, or video URL
    std::string content_type;  // "text", "audio", "video"
    Language source_language;
    Language target_language;
    TranslationSettings settings;
    std::function<void(const TextTranslation&)> on_text_complete;
    std::function<void(const AudioTranslation&)> on_audio_complete;
    std::function<void(const VideoTranslation&)> on_video_complete;
    std::function<void(const std::string& error)> on_error;
    int64_t created_at = 0;
    int priority = 0;
};

// ============================================
// TRANSLATION MANAGER
// ============================================

/**
 * Translation Manager - Main class
 */
class TranslationManager {
public:
    static TranslationManager& getInstance();

    // ============================================
    // INITIALIZATION
    // ============================================

    /**
     * Initialize translation service
     */
    bool initialize(const std::string& api_key = "");

    /**
     * Shutdown translation service
     */
    void shutdown();

    /**
     * Check if service is available
     */
    bool isAvailable() const;

    // ============================================
    // TEXT TRANSLATION
    // ============================================

    /**
     * Translate text (synchronous)
     */
    TextTranslation translateText(
        const std::string& text,
        Language target_language,
        Language source_language = Language::AUTO_DETECT);

    /**
     * Translate text (asynchronous)
     */
    std::string queueTextTranslation(
        const std::string& text,
        Language target_language,
        std::function<void(const TextTranslation&)> callback);

    /**
     * Batch translate multiple texts
     */
    std::vector<TextTranslation> translateTextBatch(
        const std::vector<std::string>& texts,
        Language target_language);

    /**
     * Detect language
     */
    Language detectLanguage(const std::string& text);

    /**
     * Get supported languages
     */
    std::vector<LanguageInfo> getSupportedLanguages();

    // ============================================
    // AUDIO TRANSLATION
    // ============================================

    /**
     * Translate audio (speech-to-speech)
     */
    AudioTranslation translateAudio(
        const std::string& audio_url,
        Language target_language,
        Language source_language = Language::AUTO_DETECT);

    /**
     * Translate audio (asynchronous)
     */
    std::string queueAudioTranslation(
        const std::string& audio_url,
        Language target_language,
        std::function<void(const AudioTranslation&)> callback);

    /**
     * Real-time audio translation (streaming)
     */
    bool startRealTimeAudioTranslation(
        Language target_language,
        std::function<void(const AudioTranslation&)> callback);

    /**
     * Stop real-time translation
     */
    void stopRealTimeAudioTranslation();

    /**
     * Speech-to-text
     */
    std::string speechToText(
        const std::string& audio_url,
        Language language = Language::AUTO_DETECT);

    /**
     * Text-to-speech
     */
    std::string textToSpeech(
        const std::string& text,
        Language language,
        const std::string& voice = "default");

    // ============================================
    // VIDEO TRANSLATION
    // ============================================

    /**
     * Translate video with subtitles
     */
    VideoTranslation translateVideo(
        const std::string& video_url,
        Language target_language,
        bool generate_subtitles = true,
        bool generate_voice_over = false);

    /**
     * Translate video (asynchronous)
     */
    std::string queueVideoTranslation(
        const std::string& video_url,
        Language target_language,
        std::function<void(const VideoTranslation&)> callback);

    /**
     * Generate subtitles
     */
    std::vector<Subtitle> generateSubtitles(
        const std::string& video_url,
        Language language = Language::AUTO_DETECT);

    /**
     * Burn subtitles into video
     */
    std::string burnSubtitles(
        const std::string& video_url,
        const std::vector<Subtitle>& subtitles,
        const std::string& style = "default");

    /**
     * Extract audio from video
     */
    std::string extractAudioFromVideo(const std::string& video_url);

    // ============================================
    // SUBTITLES
    // ============================================

    /**
     * Load subtitles from file
     */
    std::vector<Subtitle> loadSubtitles(
        const std::string& file_path,
        const std::string& format = "srt");

    /**
     * Save subtitles to file
     */
    bool saveSubtitles(
        const std::vector<Subtitle>& subtitles,
        const std::string& file_path,
        const std::string& format = "srt");

    /**
     * Translate subtitles
     */
    std::vector<Subtitle> translateSubtitles(
        const std::vector<Subtitle>& subtitles,
        Language target_language);

    /**
     * Sync subtitles with video
     */
    std::vector<Subtitle> syncSubtitles(
        const std::vector<Subtitle>& subtitles,
        float offset_seconds);

    // ============================================
    // SETTINGS
    // ============================================

    /**
     * Set default translation settings
     */
    void setDefaultSettings(const TranslationSettings& settings);

    /**
     * Get default translation settings
     */
    TranslationSettings getDefaultSettings() const;

    /**
     * Set target language
     */
    void setTargetLanguage(Language language);

    /**
     * Get target language
     */
    Language getTargetLanguage() const;

    // ============================================
    // CACHE & OFFLINE
    // ============================================

    /**
     * Enable offline mode
     */
    bool enableOfflineMode();

    /**
     * Download language pack
     */
    bool downloadLanguagePack(Language language);

    /**
     * Delete language pack
     */
    bool deleteLanguagePack(Language language);

    /**
     * Clear translation cache
     */
    void clearCache();

    // ============================================
    // STATISTICS
    // ============================================

    /**
     * Get translation statistics
     */
    struct TranslationStats {
        int total_translations = 0;
        int text_translations = 0;
        int audio_translations = 0;
        int video_translations = 0;
        int64_t total_processing_time_ms = 0;
        std::map<Language, int> translations_by_language;
    };

    TranslationStats getStatistics() const;

    // ============================================
    // UTILITIES
    // ============================================

    /**
     * Get language name
     */
    static std::string getLanguageName(Language language);

    /**
     * Get language flag emoji
     */
    static std::string getLanguageFlag(Language language);

    /**
     * Get ISO language code
     */
    static std::string getLanguageISOCode(Language language);

    /**
     * Parse language from ISO code
     */
    static Language parseLanguageFromISOCode(const std::string& iso_code);

private:
    TranslationManager() = default;
    ~TranslationManager() = default;
    TranslationManager(const TranslationManager&) = delete;
    TranslationManager& operator=(const TranslationManager&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;

    TranslationSettings default_settings_;
    std::queue<TranslationTask> task_queue_;
    std::mutex queue_mutex_;
    std::vector<std::thread> worker_threads_;
    bool running_ = false;

    // Internal methods
    void processQueue();
    TextTranslation translateTextInternal(const std::string& text, Language target, Language source);
    AudioTranslation translateAudioInternal(const std::string& audio_url, Language target, Language source);
    VideoTranslation translateVideoInternal(const std::string& video_url, Language target);
};

} // namespace translation
} // namespace liberty_reach
} // namespace td
