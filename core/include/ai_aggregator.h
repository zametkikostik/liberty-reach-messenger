/**
 * Liberty Reach - AI Aggregator Module
 * OpenRouter integration for multi-provider AI models
 * GPT-4, Claude, Llama, Mistral, and more
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace ai {

// ============================================
// AI PROVIDERS
// ============================================

/**
 * AI Provider type
 */
enum class AIProvider {
    OPENAI,           // GPT-4, GPT-3.5
    ANTHROPIC,        // Claude
    GOOGLE,           // Gemini
    META,             // Llama
    MISTRAL,          // Mistral
    COHERE,           // Command
    PALM,             // PaLM 2
    TOGETHER,         // Various open models
    ANTHROPIC_LEGACY, // Claude 2
    OPENROUTER        // OpenRouter (aggregator)
};

/**
 * AI Model info
 */
struct AIModel {
    std::string id;
    std::string name;
    AIProvider provider;
    std::string description;
    int context_window_tokens = 4096;
    float price_per_1k_input = 0.0f;
    float price_per_1k_output = 0.0f;
    bool supports_vision = false;
    bool supports_function_calling = false;
    bool supports_json_mode = false;
    float max_tokens_per_second = 100.0f;
};

// ============================================
// CHAT COMPLETION
// ============================================

/**
 * Chat message role
 */
enum class MessageRole {
    SYSTEM,
    USER,
    ASSISTANT,
    FUNCTION,
    TOOL
};

/**
 * Chat message
 */
struct ChatMessage {
    MessageRole role;
    std::string content;
    std::string name;  // Optional
    std::string function_call;  // Optional
    std::vector<uint8_t> image_data;  // For vision models
    std::string image_url;  // For vision models
};

/**
 * Function definition for function calling
 */
struct FunctionDefinition {
    std::string name;
    std::string description;
    std::map<std::string, std::string> parameters;  // JSON Schema
};

/**
 * Chat completion request
 */
struct ChatCompletionRequest {
    std::string model;  // Model ID
    std::vector<ChatMessage> messages;
    float temperature = 1.0f;
    float top_p = 1.0f;
    int max_tokens = 2048;
    float presence_penalty = 0.0f;
    float frequency_penalty = 0.0f;
    bool stream = false;
    std::vector<std::string> stop;
    std::vector<FunctionDefinition> functions;
    std::string function_call;  // "auto", "none", or function name
    bool json_mode = false;
    std::string system_prompt;
};

/**
 * Chat completion response
 */
struct ChatCompletionResponse {
    std::string id;
    std::string content;
    std::string model;
    int64_t created_at = 0;
    int tokens_used = 0;
    int prompt_tokens = 0;
    int completion_tokens = 0;
    float total_cost_usd = 0.0f;
    std::string finish_reason;  // "stop", "length", "function_call"
    std::string function_call_name;
    std::string function_call_arguments;
    bool is_streaming = false;
    std::string error_message;
};

// ============================================
// STREAMING
// ============================================

/**
 * Stream chunk
 */
struct StreamChunk {
    std::string content;
    std::string role;
    bool is_finished = false;
    std::string finish_reason;
    int64_t created_at = 0;
};

/**
 * Stream callback
 */
using StreamCallback = std::function<void(const StreamChunk&)>;

// ============================================
// EMBEDDINGS
// ============================================

/**
 * Embedding result
 */
struct EmbeddingResult {
    std::vector<float> embedding;
    std::string model;
    int tokens_used = 0;
};

// ============================================
// IMAGE GENERATION
// ============================================

/**
 * Image generation request
 */
struct ImageGenerationRequest {
    std::string prompt;
    std::string negative_prompt;
    int width = 512;
    int height = 512;
    int num_images = 1;
    std::string style;  // "photorealistic", "artistic", "anime"
    int steps = 50;
    float guidance_scale = 7.5f;
    std::string model;
};

/**
 * Image generation result
 */
struct ImageGenerationResult {
    std::vector<std::string> image_urls;
    std::vector<std::string> image_data;  // Base64
    std::string model;
    int64_t generation_time_ms = 0;
    float cost_usd = 0.0f;
};

// ============================================
// TEXT-TO-SPEECH
// ============================================

/**
 * TTS request
 */
struct TTSRequest {
    std::string text;
    std::string voice;  // Voice ID
    std::string model;
    float speed = 1.0f;
    std::string format;  // "mp3", "wav", "opus"
};

/**
 * TTS result
 */
struct TTSResult {
    std::string audio_url;
    std::vector<uint8_t> audio_data;
    float duration_seconds = 0.0f;
    std::string format;
    float cost_usd = 0.0f;
};

// ============================================
// SPEECH-TO-TEXT
// ============================================

/**
 * STT request
 */
struct STTRequest {
    std::string audio_url;
    std::vector<uint8_t> audio_data;
    std::string language;  // Auto-detect if empty
    std::string model;
    bool show_speaker_labels = false;
    bool add_timestamps = false;
};

/**
 * STT result
 */
struct STTResult {
    std::string text;
    std::string language;
    float confidence = 0.0f;
    float duration_seconds = 0.0f;
    std::vector<std::map<std::string, std::string>> segments;
    std::string error_message;
};

// ============================================
// AI AGGREGATOR
// ============================================

/**
 * AI Aggregator Manager
 */
class AIAggregator {
public:
    static AIAggregator& getInstance();

    // ============================================
    // INITIALIZATION
    // ============================================

    /**
     * Initialize AI aggregator
     */
    bool initialize(const std::string& openrouter_api_key = "");

    /**
     * Shutdown AI aggregator
     */
    void shutdown();

    /**
     * Check if service is available
     */
    bool isAvailable() const;

    // ============================================
    // MODELS
    // ============================================

    /**
     * Get available models
     */
    std::vector<AIModel> getAvailableModels();

    /**
     * Get model by ID
     */
    AIModel getModel(const std::string& model_id);

    /**
     * Get models by provider
     */
    std::vector<AIModel> getModelsByProvider(AIProvider provider);

    /**
     * Get recommended model for task
     */
    AIModel getRecommendedModel(
        const std::string& task,  // "chat", "code", "vision", etc.
        int context_length = 4096);

    // ============================================
    // CHAT COMPLETION
    // ============================================

    /**
     * Chat completion (synchronous)
     */
    ChatCompletionResponse chat(const ChatCompletionRequest& request);

    /**
     * Chat completion (streaming)
     */
    bool chatStream(
        const ChatCompletionRequest& request,
        StreamCallback callback);

    /**
     * Simple chat
     */
    std::string simpleChat(
        const std::string& message,
        const std::string& system_prompt = "",
        const std::string& model = "openai/gpt-3.5-turbo");

    /**
     * Chat with context
     */
    std::string chatWithContext(
        const std::vector<ChatMessage>& messages,
        const std::string& model = "openai/gpt-4");

    // ============================================
    // SPECIALIZED AI FUNCTIONS
    // ============================================

    /**
     * Code generation
     */
    std::string generateCode(
        const std::string& prompt,
        const std::string& language = "python",
        const std::string& model = "openai/gpt-4");

    /**
     * Code review
     */
    std::string reviewCode(
        const std::string& code,
        const std::string& language = "python");

    /**
     * Text summarization
     */
    std::string summarizeText(
        const std::string& text,
        int max_length = 200);

    /**
     * Text translation
     */
    std::string translateText(
        const std::string& text,
        const std::string& target_language,
        const std::string& source_language = "auto");

    /**
     * Question answering
     */
    std::string answerQuestion(
        const std::string& question,
        const std::string& context = "");

    /**
     * Creative writing
     */
    std::string creativeWriting(
        const std::string& prompt,
        const std::string& style = "creative");

    // ============================================
    // VISION
    // ============================================

    /**
     * Image analysis
     */
    std::string analyzeImage(
        const std::string& image_url,
        const std::string& prompt = "What's in this image?");

    /**
     * OCR (text extraction from image)
     */
    std::string extractTextFromImage(
        const std::string& image_url);

    // ============================================
    // EMBEDDINGS
    // ============================================

    /**
     * Generate embeddings
     */
    EmbeddingResult generateEmbedding(
        const std::string& text,
        const std::string& model = "openai/text-embedding-ada-002");

    /**
     * Generate batch embeddings
     */
    std::vector<EmbeddingResult> generateBatchEmbeddings(
        const std::vector<std::string>& texts,
        const std::string& model = "openai/text-embedding-ada-002");

    // ============================================
    // IMAGE GENERATION
    // ============================================

    /**
     * Generate image
     */
    ImageGenerationResult generateImage(
        const ImageGenerationRequest& request);

    /**
     * Simple image generation
     */
    std::string generateImageSimple(
        const std::string& prompt,
        const std::string& style = "photorealistic");

    // ============================================
    // TEXT-TO-SPEECH
    // ============================================

    /**
     * Generate speech
     */
    TTSResult generateSpeech(const TTSRequest& request);

    /**
     * Simple TTS
     */
    std::string simpleTTS(
        const std::string& text,
        const std::string& voice = "default");

    // ============================================
    // SPEECH-TO-TEXT
    // ============================================

    /**
     * Transcribe audio
     */
    STTResult transcribeAudio(const STTRequest& request);

    /**
     * Simple transcription
     */
    std::string simpleTranscribe(const std::string& audio_url);

    // ============================================
    // PROVIDER MANAGEMENT
    // ============================================

    /**
     * Add API key for provider
     */
    bool addAPIKey(AIProvider provider, const std::string& api_key);

    /**
     * Remove API key
     */
    bool removeAPIKey(AIProvider provider);

    /**
     * Get current provider
     */
    AIProvider getCurrentProvider() const;

    /**
     * Set default provider
     */
    bool setDefaultProvider(AIProvider provider);

    /**
     * Get usage statistics
     */
    std::map<std::string, float> getUsageByProvider();

    // ============================================
    // OPENROUTER SPECIFIC
    // ============================================

    /**
     * Get OpenRouter models
     */
    std::vector<AIModel> getOpenRouterModels();

    /**
     * Get OpenRouter pricing
     */
    std::map<std::string, float> getOpenRouterPricing();

    /**
     * Get OpenRouter stats
     */
    std::map<std::string, uint64_t> getOpenRouterStats();

    // ============================================
    // STATISTICS
    // ============================================

    /**
     * Get usage statistics
     */
    struct UsageStats {
        int total_requests = 0;
        int total_tokens_used = 0;
        float total_cost_usd = 0.0f;
        std::map<std::string, int> requests_by_model;
        std::map<std::string, int> requests_by_provider;
        int64_t total_time_ms = 0;
    };

    UsageStats getUsageStats() const;

    /**
     * Clear usage stats
     */
    void clearUsageStats();

    // ============================================
    // CACHING
    // ============================================

    /**
     * Enable response caching
     */
    bool enableCaching(bool enable);

    /**
     * Clear cache
     */
    bool clearCache();

    /**
     * Get cache size
     */
    uint64_t getCacheSize() const;

private:
    AIAggregator() = default;
    ~AIAggregator() = default;
    AIAggregator(const AIAggregator&) = delete;
    AIAggregator& operator=(const AIAggregator&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;

    std::string openrouter_api_key_;
    std::map<AIProvider, std::string> api_keys_;
    AIProvider default_provider_ = AIProvider::OPENROUTER;
    bool initialized_ = false;
    UsageStats stats_;

    // Internal methods
    ChatCompletionResponse callOpenRouter(const ChatCompletionRequest& request);
    ChatCompletionResponse callProvider(
        AIProvider provider,
        const ChatCompletionRequest& request);
    std::string providerToModelName(AIProvider provider);
};

} // namespace ai
} // namespace liberty_reach
} // namespace td
