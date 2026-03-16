//! Liberty Reach Hybrid AI Engine
//!
//! Implements:
//! - Local Ollama inference (primary)
//! - OpenRouter API fallback (secondary)
//! - Anonymous request handling
//! - Automatic failover

use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

use crate::config::Config;

/// AI Provider types
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AiProvider {
    Ollama,
    OpenRouter,
}

/// AI Model configuration
#[derive(Debug, Clone)]
pub struct AiModelConfig {
    pub ollama_url: String,
    pub ollama_model: String,
    pub openrouter_url: String,
    pub openrouter_api_key: String,
    pub openrouter_model: String,
    pub timeout_secs: u64,
    pub max_retries: u32,
}

impl Default for AiModelConfig {
    fn default() -> Self {
        Self {
            ollama_url: "http://127.0.0.1:11434".to_string(),
            ollama_model: "qwen2.5:7b".to_string(),
            openrouter_url: "https://openrouter.ai/api/v1".to_string(),
            openrouter_api_key: String::new(),
            openrouter_model: "qwen/qwen-2.5-72b-instruct:free".to_string(),
            timeout_secs: 30,
            max_retries: 3,
        }
    }
}

impl AiModelConfig {
    pub fn from_config(config: &Config) -> Self {
        Self {
            ollama_url: config.ollama_url.clone().unwrap_or_else(|| "http://127.0.0.1:11434".to_string()),
            ollama_model: config.ollama_model.clone().unwrap_or_else(|| "qwen2.5:7b".to_string()),
            openrouter_url: config.openrouter_url.clone().unwrap_or_else(|| "https://openrouter.ai/api/v1".to_string()),
            openrouter_api_key: config.openrouter_api_key.clone().unwrap_or_default(),
            openrouter_model: config.openrouter_model.clone().unwrap_or_else(|| "qwen/qwen-2.5-72b-instruct:free".to_string()),
            timeout_secs: config.ai_timeout_secs.unwrap_or(30),
            max_retries: config.ai_max_retries.unwrap_or(3),
        }
    }
}

/// AI Request structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiRequest {
    pub prompt: String,
    pub system_prompt: Option<String>,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
}

/// AI Response structure
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
    OllamaConnection(String),
    OllamaError(String),
    OllamaParse(String),
    OpenRouterConnection(String),
    OpenRouterError(String),
    OpenRouterParse(String),
    OpenRouterAuth,
    OpenRouterRateLimit,
    AllProvidersFailed,
}

impl std::fmt::Display for AiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AiError::OllamaConnection(e) => write!(f, "Ollama connection: {}", e),
            AiError::OllamaError(e) => write!(f, "Ollama error: {}", e),
            AiError::OllamaParse(e) => write!(f, "Ollama parse: {}", e),
            AiError::OpenRouterConnection(e) => write!(f, "OpenRouter connection: {}", e),
            AiError::OpenRouterError(e) => write!(f, "OpenRouter error: {}", e),
            AiError::OpenRouterParse(e) => write!(f, "OpenRouter parse: {}", e),
            AiError::OpenRouterAuth => write!(f, "OpenRouter: Unauthorized"),
            AiError::OpenRouterRateLimit => write!(f, "OpenRouter: Rate limited"),
            AiError::AllProvidersFailed => write!(f, "All AI providers failed"),
        }
    }
}

/// Ollama API structures
#[derive(Debug, Serialize, Deserialize)]
struct OllamaGenerateRequest {
    model: String,
    prompt: String,
    system: String,
    stream: Option<bool>,
    options: Option<OllamaOptions>,
}

#[derive(Debug, Serialize, Deserialize)]
struct OllamaOptions {
    temperature: f32,
    num_predict: i32,
}

#[derive(Debug, Serialize, Deserialize)]
struct OllamaGenerateResponse {
    response: String,
}

/// OpenRouter API structures
#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterRequest {
    model: String,
    messages: Vec<OpenRouterMessage>,
    max_tokens: u32,
    temperature: f32,
    stream: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterMessage {
    role: String,
    content: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterResponse {
    choices: Vec<OpenRouterChoice>,
    usage: OpenRouterUsage,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterChoice {
    message: OpenRouterMessage,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenRouterUsage {
    prompt_tokens: u32,
    completion_tokens: u32,
    total_tokens: u32,
}

/// AI Manager for hybrid inference
pub struct AiManager {
    config: AiModelConfig,
    client: Client,
    current_provider: Arc<RwLock<AiProvider>>,
    fallback_count: Arc<RwLock<u32>>,
}

impl AiManager {
    /// Create new AI manager
    pub fn new(config: AiModelConfig) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(config.timeout_secs))
            .user_agent("Liberty-Reach-AI/0.6.0")
            .build()
            .expect("Failed to create HTTP client");

        Self {
            config,
            client,
            current_provider: Arc::new(RwLock::new(AiProvider::Ollama)),
            fallback_count: Arc::new(RwLock::new(0)),
        }
    }

    /// Check if Ollama is available
    pub async fn check_ollama_health(&self) -> bool {
        let url = format!("{}/api/tags", self.config.ollama_url);
        match self.client.get(&url).send().await {
            Ok(resp) => resp.status().is_success(),
            Err(_) => false,
        }
    }

    /// Process message with automatic failover
    pub async fn process_message(&self, request: AiRequest) -> Result<AiResponse, AiError> {
        let mut last_error: Option<AiError> = None;
        
        for _attempt in 0..self.config.max_retries {
            let provider = *self.current_provider.read().await;
            debug!("AI request using {:?}", provider);
            
            match self.try_provider(provider, &request).await {
                Ok(response) => {
                    *self.fallback_count.write().await = 0;
                    if provider == AiProvider::OpenRouter {
                        *self.current_provider.write().await = AiProvider::Ollama;
                    }
                    return Ok(response);
                }
                Err(e) => {
                    warn!("AI provider {:?} failed: {:?}", provider, e);
                    last_error = Some(e.clone());
                    
                    if provider == AiProvider::Ollama {
                        *self.current_provider.write().await = AiProvider::OpenRouter;
                        *self.fallback_count.write().await += 1;
                    }
                }
            }
        }
        
        Err(last_error.unwrap_or(AiError::AllProvidersFailed))
    }

    /// Try a specific provider
    async fn try_provider(&self, provider: AiProvider, request: &AiRequest) -> Result<AiResponse, AiError> {
        let start_time = std::time::Instant::now();
        let result = match provider {
            AiProvider::Ollama => self.try_ollama(request).await,
            AiProvider::OpenRouter => self.try_openrouter(request).await,
        };
        
        result.map(|mut response| {
            response.latency_ms = start_time.elapsed().as_millis() as u64;
            response
        })
    }

    /// Try Ollama (local)
    async fn try_ollama(&self, request: &AiRequest) -> Result<AiResponse, AiError> {
        let url = format!("{}/api/generate", self.config.ollama_url);
        
        let ollama_request = OllamaGenerateRequest {
            model: self.config.ollama_model.clone(),
            prompt: request.prompt.clone(),
            system: request.system_prompt.clone().unwrap_or_default(),
            stream: Some(false),
            options: Some(OllamaOptions {
                temperature: request.temperature.unwrap_or(0.7),
                num_predict: request.max_tokens.unwrap_or(512) as i32,
            }),
        };

        let response = self.client
            .post(&url)
            .json(&ollama_request)
            .send()
            .await
            .map_err(|e| AiError::OllamaConnection(e.to_string()))?;

        if !response.status().is_success() {
            return Err(AiError::OllamaError(format!("Status: {}", response.status())));
        }

        let ollama_response: OllamaGenerateResponse = response
            .json()
            .await
            .map_err(|e| AiError::OllamaParse(e.to_string()))?;

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
        
        let anonymized_prompt = self.anonymize_prompt(&request.prompt);
        
        let openrouter_request = OpenRouterRequest {
            model: self.config.openrouter_model.clone(),
            messages: vec![
                OpenRouterMessage {
                    role: "system".to_string(),
                    content: request.system_prompt.clone().unwrap_or_else(|| 
                        "You are a helpful AI assistant for Liberty Reach messenger.".to_string()
                    ),
                },
                OpenRouterMessage {
                    role: "user".to_string(),
                    content: anonymized_prompt,
                },
            ],
            max_tokens: request.max_tokens.unwrap_or(512),
            temperature: request.temperature.unwrap_or(0.7),
            stream: false,
        };

        let response = self.client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.config.openrouter_api_key))
            .header("HTTP-Referer", "https://liberty-reach.com")
            .header("X-Title", "Liberty Reach Messenger")
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
            .map_err(|e| AiError::OpenRouterParse(e.to_string()))?;

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

    /// Anonymize prompt - remove PII and metadata
    fn anonymize_prompt(&self, prompt: &str) -> String {
        prompt
            .replace("user:", "[USER]")
            .replace("username:", "[USERNAME]")
            .replace("@", " [AT] ")
            .replace("+", " [PHONE] ")
    }

    /// Process incoming message and auto-suggest response
    pub async fn process_incoming_message(
        &self,
        message: &str,
        context: Option<&str>,
    ) -> Result<AiResponse, AiError> {
        let system_prompt = r#"You are an AI assistant for Liberty Reach secure messenger.
Your tasks:
1. Suggest helpful responses to incoming messages
2. Detect hidden meanings or subtext when asked
3. Keep suggestions concise and natural
4. Respect user privacy - never ask for personal information

Respond in the same language as the incoming message."#;

        let prompt = if let Some(ctx) = context {
            format!("Context: {}\n\nIncoming message: {}\n\nSuggest a response:", ctx, message)
        } else {
            format!("Incoming message: {}\n\nSuggest a response:", message)
        };

        self.process_message(AiRequest {
            prompt,
            system_prompt: Some(system_prompt.to_string()),
            max_tokens: Some(256),
            temperature: Some(0.8),
        }).await
    }

    /// Get current provider status
    pub async fn get_provider_status(&self) -> (AiProvider, bool, u32) {
        let provider = *self.current_provider.read().await;
        let fallback_count = *self.fallback_count.read().await;
        let ollama_healthy = self.check_ollama_health().await;
        (provider, ollama_healthy, fallback_count)
    }
}

/// Start AI manager in background
pub fn start_ai_manager(config: Config) -> Arc<AiManager> {
    let ai_config = AiModelConfig::from_config(&config);
    let manager = Arc::new(AiManager::new(ai_config));
    
    // Start health check in background
    let manager_clone = Arc::clone(&manager);
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            let (provider, healthy, fallbacks) = manager_clone.get_provider_status().await;
            debug!("AI Status: provider={:?}, ollama_healthy={}, fallbacks={}", provider, healthy, fallbacks);
        }
    });
    
    manager
}
