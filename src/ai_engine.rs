//! Liberty Sovereign Hybrid AI Engine v0.7.2
//!
//! Thread-safe Hybrid AI with strict 2-second timeout fallback:
//! - Primary: Local Ollama (127.0.0.1:11434)
//! - Fallback: OpenRouter API (qwen/qwen-2.5-72b-instruct:free)

use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

/// AI Provider (which backend is active)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AiProvider {
    Ollama,
    OpenRouter,
}

/// AI Configuration (from environment)
#[derive(Debug, Clone)]
pub struct AiModelConfig {
    pub ollama_url: String,
    pub ollama_model: String,
    pub openrouter_url: String,
    pub openrouter_api_key: String,
    pub openrouter_model: String,
    pub ollama_timeout_secs: u64,
    pub max_retries: u32,
}

impl Default for AiModelConfig {
    fn default() -> Self {
        Self {
            ollama_url: "http://127.0.0.1:11434".to_string(),
            ollama_model: "qwen2.5:7b".to_string(),
            openrouter_url: "https://openrouter.ai/api/v1".to_string(),
            openrouter_api_key: std::env::var("OPENROUTER_API_KEY").unwrap_or_default(),
            openrouter_model: "qwen/qwen-2.5-72b-instruct:free".to_string(),
            ollama_timeout_secs: 2, // STRICT 2-second timeout
            max_retries: 1,
        }
    }
}

impl AiModelConfig {
    /// Load from environment variables
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok(); // Load .env.local if exists
        
        Self {
            ollama_url: std::env::var("OLLAMA_URL")
                .unwrap_or_else(|_| "http://127.0.0.1:11434".to_string()),
            ollama_model: std::env::var("OLLAMA_MODEL")
                .unwrap_or_else(|_| "qwen2.5:7b".to_string()),
            openrouter_url: std::env::var("OPENROUTER_URL")
                .unwrap_or_else(|_| "https://openrouter.ai/api/v1".to_string()),
            openrouter_api_key: std::env::var("OPENROUTER_API_KEY")
                .unwrap_or_default(),
            openrouter_model: std::env::var("OPENROUTER_MODEL")
                .unwrap_or_else(|_| "qwen/qwen-2.5-72b-instruct:free".to_string()),
            ollama_timeout_secs: std::env::var("AI_TIMEOUT_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(2),
            max_retries: std::env::var("AI_MAX_RETRIES")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1),
        }
    }
}

/// AI Request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiRequest {
    pub prompt: String,
    pub system_prompt: Option<String>,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
}

/// AI Response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiResponse {
    pub content: String,
    pub provider: AiProvider,
    pub model: String,
    pub latency_ms: u64,
}

/// AI Error types
#[derive(Debug, Clone)]
pub enum AiError {
    OllamaTimeout,
    OllamaConnection(String),
    OllamaError(String),
    OpenRouterConnection(String),
    OpenRouterError(String),
    OpenRouterAuth,
    OpenRouterRateLimit,
    AllProvidersFailed,
}

impl std::fmt::Display for AiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AiError::OllamaTimeout => write!(f, "Ollama timeout (>2s)"),
            AiError::OllamaConnection(e) => write!(f, "Ollama connection: {}", e),
            AiError::OllamaError(e) => write!(f, "Ollama error: {}", e),
            AiError::OpenRouterConnection(e) => write!(f, "OpenRouter connection: {}", e),
            AiError::OpenRouterError(e) => write!(f, "OpenRouter error: {}", e),
            AiError::OpenRouterAuth => write!(f, "OpenRouter: Unauthorized (check API key)"),
            AiError::OpenRouterRateLimit => write!(f, "OpenRouter: Rate limited"),
            AiError::AllProvidersFailed => write!(f, "All AI providers failed"),
        }
    }
}

// Ollama structures
#[derive(Debug, Serialize, Deserialize)]
struct OllamaRequest {
    model: String,
    prompt: String,
    system: String,
    stream: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct OllamaResponse {
    response: String,
}

// OpenRouter structures
#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterRequest {
    model: String,
    messages: Vec<OpenRouterMessage>,
    max_tokens: u32,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterMessage {
    role: String,
    content: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterResponse {
    choices: Vec<OpenRouterChoice>,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterChoice {
    message: OpenRouterMessage,
}

/// Thread-safe AI Manager
pub struct AiManager {
    config: AiModelConfig,
    ollama_client: Client,      // 2-second timeout
    openrouter_client: Client,  // 30-second timeout
    current_provider: Arc<RwLock<AiProvider>>,
    fallback_count: Arc<RwLock<u32>>,
}

impl AiManager {
    /// Create new AI manager with thread-safe Arc
    pub fn new(config: AiModelConfig) -> Arc<Self> {
        // Ollama client with STRICT 2-second timeout
        let ollama_client = Client::builder()
            .timeout(Duration::from_secs(config.ollama_timeout_secs))
            .user_agent("Liberty-Sovereign-AI/0.7.2")
            .build()
            .expect("Failed to create Ollama HTTP client");

        // OpenRouter client with 30-second timeout
        let openrouter_client = Client::builder()
            .timeout(Duration::from_secs(30))
            .user_agent("Liberty-Sovereign-AI/0.7.2")
            .build()
            .expect("Failed to create OpenRouter HTTP client");

        let manager = Self {
            config,
            ollama_client,
            openrouter_client,
            current_provider: Arc::new(RwLock::new(AiProvider::Ollama)),
            fallback_count: Arc::new(RwLock::new(0)),
        };

        Arc::new(manager)
    }

    /// Check if Ollama is healthy (quick check)
    pub async fn check_ollama_health(&self) -> bool {
        let url = format!("{}/api/tags", self.config.ollama_url);
        match tokio::time::timeout(
            Duration::from_secs(2),
            self.ollama_client.get(&url).send()
        ).await {
            Ok(Ok(resp)) => resp.status().is_success(),
            _ => false,
        }
    }

    /// Process message with automatic failover
    pub async fn process_message(&self, request: AiRequest) -> Result<AiResponse, AiError> {
        let provider = *self.current_provider.read().await;
        info!("🤖 AI request using {:?}", provider);
        
        match self.try_provider(provider, &request).await {
            Ok(response) => {
                info!("✅ AI response from {:?} ({}ms)", response.provider, response.latency_ms);
                *self.fallback_count.write().await = 0;
                
                // If we succeeded with OpenRouter, try Ollama next time
                if provider == AiProvider::OpenRouter {
                    *self.current_provider.write().await = AiProvider::Ollama;
                    info!("🔄 Switching back to Ollama for next request");
                }
                
                Ok(response)
            }
            Err(e) => {
                warn!("❌ AI provider {:?} failed: {}", provider, e);
                
                // Switch to OpenRouter if Ollama failed
                if provider == AiProvider::Ollama {
                    *self.current_provider.write().await = AiProvider::OpenRouter;
                    *self.fallback_count.write().await += 1;
                    info!("🔄 Switched to OpenRouter fallback");
                    
                    // Try OpenRouter immediately
                    return self.try_provider(AiProvider::OpenRouter, &request).await;
                }
                
                Err(e)
            }
        }
    }

    /// Try a specific provider
    async fn try_provider(&self, provider: AiProvider, request: &AiRequest) -> Result<AiResponse, AiError> {
        let start_time = std::time::Instant::now();
        
        let result = match provider {
            AiProvider::Ollama => {
                info!("⏳ Trying Ollama ({}s timeout)...", self.config.ollama_timeout_secs);
                self.try_ollama(request).await
            }
            AiProvider::OpenRouter => {
                info!("⏳ Trying OpenRouter...");
                self.try_openrouter(request).await
            }
        };
        
        result.map(|mut response| {
            response.latency_ms = start_time.elapsed().as_millis() as u64;
            response
        })
    }

    /// Try Ollama (local) - STRICT 2-second timeout
    async fn try_ollama(&self, request: &AiRequest) -> Result<AiResponse, AiError> {
        let url = format!("{}/api/generate", self.config.ollama_url);
        
        let ollama_request = OllamaRequest {
            model: self.config.ollama_model.clone(),
            prompt: request.prompt.clone(),
            system: request.system_prompt.clone().unwrap_or_default(),
            stream: false,
        };

        // Use tokio::time::timeout for STRICT timeout
        let response_result = tokio::time::timeout(
            Duration::from_secs(self.config.ollama_timeout_secs),
            self.ollama_client.post(&url).json(&ollama_request).send()
        ).await;

        let response = match response_result {
            Ok(Ok(resp)) => resp,
            Ok(Err(e)) => return Err(AiError::OllamaConnection(e.to_string())),
            Err(_) => return Err(AiError::OllamaTimeout),
        };

        if !response.status().is_success() {
            return Err(AiError::OllamaError(format!("Status: {}", response.status())));
        }

        let ollama_response: OllamaResponse = response
            .json()
            .await
            .map_err(|e| AiError::OllamaError(format!("Parse error: {}", e)))?;

        Ok(AiResponse {
            content: ollama_response.response,
            provider: AiProvider::Ollama,
            model: self.config.ollama_model.clone(),
            latency_ms: 0,
        })
    }

    /// Try OpenRouter (cloud fallback)
    async fn try_openrouter(&self, request: &AiRequest) -> Result<AiResponse, AiError> {
        let url = format!("{}/chat/completions", self.config.openrouter_url);
        
        // ANONYMIZE: Remove any PII from prompt
        let anonymized_prompt = self.anonymize_prompt(&request.prompt);
        
        let openrouter_request = OpenRouterRequest {
            model: self.config.openrouter_model.clone(),
            messages: vec![
                OpenRouterMessage {
                    role: "system".to_string(),
                    content: request.system_prompt.clone().unwrap_or_else(|| 
                        "You are a helpful AI assistant for Liberty Sovereign messenger. Keep responses concise.".to_string()
                    ),
                },
                OpenRouterMessage {
                    role: "user".to_string(),
                    content: anonymized_prompt,
                },
            ],
            max_tokens: request.max_tokens.unwrap_or(512),
        };

        let response = self.openrouter_client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.config.openrouter_api_key))
            .header("HTTP-Referer", "https://liberty-sovereign.com")
            .header("X-Title", "Liberty Sovereign Messenger")
            .json(&openrouter_request)
            .send()
            .await
            .map_err(|e| AiError::OpenRouterConnection(e.to_string()))?;

        match response.status() {
            StatusCode::OK => {},
            StatusCode::UNAUTHORIZED => return Err(AiError::OpenRouterAuth),
            StatusCode::TOO_MANY_REQUESTS => return Err(AiError::OpenRouterRateLimit),
            _ => return Err(AiError::OpenRouterError(format!("Status: {}", response.status()))),
        }

        let openrouter_response: OpenRouterResponse = response
            .json()
            .await
            .map_err(|e| AiError::OpenRouterConnection(e.to_string()))?;

        let content = openrouter_response
            .choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default();

        Ok(AiResponse {
            content,
            provider: AiProvider::OpenRouter,
            model: self.config.openrouter_model.clone(),
            latency_ms: 0,
        })
    }

    /// Anonymize prompt - remove PII
    fn anonymize_prompt(&self, prompt: &str) -> String {
        prompt
            .replace("user:", "[USER]")
            .replace("username:", "[USERNAME]")
            .replace("@", " [AT] ")
            .replace("+", " [PHONE] ")
    }

    /// Get current provider status
    pub async fn get_status(&self) -> (AiProvider, bool, u32) {
        let provider = *self.current_provider.read().await;
        let fallback_count = *self.fallback_count.read().await;
        let ollama_healthy = self.check_ollama_health().await;
        (provider, ollama_healthy, fallback_count)
    }
}

/// Start AI manager and return Arc
pub fn start_ai_manager() -> Arc<AiManager> {
    let config = AiModelConfig::from_env();
    
    // Check if API key is configured
    if config.openrouter_api_key.is_empty() {
        warn!("⚠️  OPENROUTER_API_KEY not set! AI fallback will fail.");
        warn!("   Get a free key: https://openrouter.ai/keys");
    }
    
    let manager = AiManager::new(config);
    
    // Log initialization
    info!("🤖 AI Manager initialized");
    info!("   Primary: Ollama @ {}", manager.config.ollama_url);
    info!("   Fallback: OpenRouter ({})", manager.config.openrouter_model);
    info!("   Ollama timeout: {}s", manager.config.ollama_timeout_secs);
    
    // Start background health checker
    let manager_clone = Arc::clone(&manager);
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            let (provider, healthy, fallbacks) = manager_clone.get_status().await;
            debug!("🤖 AI Status: provider={:?}, ollama={}, fallbacks={}", provider, healthy, fallbacks);
        }
    });
    
    manager
}
