//! Liberty Sovereign - Environment Configuration Loader
//!
//! Priority:
//! 1. System Environment Variables (CI/CD, GitHub Actions)
//! 2. .env.local file (Local development)
//! 3. Default values (Fallback)

use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    // Blockchain
    pub rpc_url: String,
    pub pocket_rpc_url: String,
    pub lava_rpc_url: String,

    // AI
    pub openrouter_api_key: Option<String>,
    pub openrouter_url: Option<String>,
    pub openrouter_model: Option<String>,
    pub ollama_url: Option<String>,
    pub ollama_model: Option<String>,
    pub ai_timeout_secs: Option<u64>,
    pub ai_max_retries: Option<u32>,

    // Storage
    pub pinata_api_key: Option<String>,
    pub pinata_secret_key: Option<String>,

    // Security
    pub secret_love_key: String,

    // Admin
    pub admin_peer_id: Option<String>,

    // P2P
    pub p2p_port: Option<u16>,

    // Build info
    pub is_ci: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            rpc_url: "https://polygon-rpc.com".to_string(),
            pocket_rpc_url: "https://poly.api.pocket.network".to_string(),
            lava_rpc_url: "https://g.w.lavanet.xyz:443/gateway/polygon/rpc-http/510353c239edb26b7ef54b675ea3dbc8".to_string(),
            openrouter_api_key: None,
            openrouter_url: Some("https://openrouter.ai/api/v1".to_string()),
            openrouter_model: Some("qwen/qwen-2.5-72b-instruct:free".to_string()),
            ollama_url: Some("http://127.0.0.1:11434".to_string()),
            ollama_model: Some("qwen2.5:7b".to_string()),
            ai_timeout_secs: Some(30),
            ai_max_retries: Some(3),
            pinata_api_key: None,
            pinata_secret_key: None,
            secret_love_key: "liberty_reach_default_salt".to_string(),
            admin_peer_id: None,
            p2p_port: Some(40000),
            is_ci: false,
        }
    }
}

impl AppConfig {
    /// Load configuration with priority: Env > .env.local > Default
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        // Load .env.local if exists (only for local dev)
        let _ = dotenvy::from_path(".env.local");
        
        // Check if running in CI
        let is_ci = env::var("CI").unwrap_or_default() == "true";
        
        // Load from environment variables (highest priority)
        let config = Self {
            // RPC URLs - prioritize from env
            rpc_url: env::var("RPC_URL")
                .or_else(|_| env::var("LAVA_RPC_URL"))
                .unwrap_or_else(|_| Self::default().rpc_url),

            pocket_rpc_url: env::var("POCKET_RPC_URL")
                .unwrap_or_else(|_| Self::default().pocket_rpc_url),

            lava_rpc_url: env::var("LAVA_RPC_URL")
                .unwrap_or_else(|_| Self::default().lava_rpc_url),

            // AI - from env only
            openrouter_api_key: env::var("OPENROUTER_API_KEY").ok(),
            openrouter_url: env::var("OPENROUTER_URL").ok().or_else(|| Self::default().openrouter_url),
            openrouter_model: env::var("OPENROUTER_MODEL").ok().or_else(|| Self::default().openrouter_model),
            ollama_url: env::var("OLLAMA_URL").ok().or_else(|| Self::default().ollama_url),
            ollama_model: env::var("OLLAMA_MODEL").ok().or_else(|| Self::default().ollama_model),
            ai_timeout_secs: env::var("AI_TIMEOUT_SECS").ok().and_then(|s| s.parse().ok()).or(Self::default().ai_timeout_secs),
            ai_max_retries: env::var("AI_MAX_RETRIES").ok().and_then(|s| s.parse().ok()).or(Self::default().ai_max_retries),

            // Storage - from env only
            pinata_api_key: env::var("PINATA_API_KEY").ok(),
            pinata_secret_key: env::var("PINATA_SECRET_KEY").ok(),

            // Security - from env or default
            secret_love_key: env::var("SECRET_LOVE_KEY")
                .unwrap_or_else(|_| Self::default().secret_love_key),

            // Admin - from env or .env.local
            admin_peer_id: env::var("ADMIN_PEER_ID").ok(),

            // P2P
            p2p_port: env::var("P2P_PORT").ok().and_then(|s| s.parse().ok()).or(Self::default().p2p_port),

            is_ci,
        };
        
        // Log configuration source
        if is_ci {
            println!("🚀 Running in CI/CD mode (GitHub Actions)");
            println!("📋 Using environment variables from secrets");
        } else {
            println!("💻 Running in Local mode");
            println!("📋 Using .env.local + environment variables");
        }
        
        // Validate required fields
        config.validate()?;
        
        Ok(config)
    }
    
    /// Validate critical configuration
    pub fn validate(&self) -> Result<(), Box<dyn std::error::Error>> {
        // RPC URL is required
        if self.rpc_url.is_empty() {
            return Err("RPC_URL is required".into());
        }
        
        // Secret key should be at least 16 characters
        if self.secret_love_key.len() < 16 {
            eprintln!("⚠️  Warning: SECRET_LOVE_KEY is too short (min 16 chars)");
        }
        
        Ok(())
    }
    
    /// Check if AI is configured
    pub fn is_ai_enabled(&self) -> bool {
        self.openrouter_api_key.is_some()
    }
    
    /// Check if IPFS is configured
    pub fn is_ipfs_enabled(&self) -> bool {
        self.pinata_api_key.is_some() && self.pinata_secret_key.is_some()
    }
    
    /// Get RPC URL with fallback chain
    pub fn get_rpc_chain(&self) -> Vec<&str> {
        vec![
            &self.rpc_url,
            &self.pocket_rpc_url,
            &self.lava_rpc_url,
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_default_config() {
        let config = AppConfig::default();
        assert!(!config.rpc_url.is_empty());
        assert_eq!(config.secret_love_key, "liberty_reach_default_salt");
    }
    
    #[test]
    fn test_validate() {
        let config = AppConfig::default();
        assert!(config.validate().is_ok());
    }
}
