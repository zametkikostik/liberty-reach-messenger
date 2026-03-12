//! Модуль интеграции с AI
//! 
//! Поддерживает:
//! - Локальный Ollama (порт 11437)
//! - OpenRouter API (ключ из .env.local)
//! - Контекстный анализ истории чата

use reqwest::Client;
use serde_json::json;
use anyhow::{Result, Context};

/// Конфигурация AI-провайдера
#[derive(Debug, Clone)]
pub enum AIProvider {
    /// Локальный Ollama
    Ollama {
        endpoint: String,
        model: String,
    },
    /// OpenRouter API
    OpenRouter {
        api_key: String,
        model: String,
        endpoint: String,
    },
}

/// Мост для интеграции с AI
pub struct AIBridge {
    client: Client,
    provider: AIProvider,
}

impl AIBridge {
    /// Создание AI моста с автоматическим выбором провайдера
    /// Приоритет: OpenRouter (если ключ есть) → Ollama
    pub fn new() -> Self {
        // Пробуем загрузить переменные окружения из .env.local
        let _ = dotenvy::from_filename(".env.local").ok();
        let _ = dotenvy::dotenv().ok();

        // Проверяем наличие ключа OpenRouter
        if let Ok(api_key) = std::env::var("OPENROUTER_API_KEY") {
            if !api_key.is_empty() && api_key.starts_with("sk-or-") {
                println!("✓ AI провайдер: OpenRouter (модель: qwen/qwen-2.5-coder-32b-instruct)");
                return Self::with_openrouter(&api_key);
            }
        }

        // Fallback на локальный Ollama
        println!("✓ AI провайдер: Ollama (локальный, порт 11437)");
        Self::with_ollama()
    }

    /// Создание с OpenRouter
    pub fn with_openrouter(api_key: &str) -> Self {
        Self {
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(60))
                .build()
                .unwrap_or_default(),
            provider: AIProvider::OpenRouter {
                api_key: api_key.to_string(),
                model: "qwen/qwen-2.5-coder-32b-instruct".to_string(),
                endpoint: "https://openrouter.ai/api/v1/chat/completions".to_string(),
            },
        }
    }

    /// Создание с локальным Ollama
    pub fn with_ollama() -> Self {
        Self {
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(60))
                .build()
                .unwrap_or_default(),
            provider: AIProvider::Ollama {
                endpoint: "http://localhost:11437/api/generate".to_string(),
                model: "qwen2.5-coder:3b".to_string(),
            },
        }
    }

    /// Простой запрос к AI
    pub async fn ask(&self, prompt: &str) -> Result<String> {
        self.ask_with_context(prompt, &[]).await
    }

    /// Запрос к AI с контекстом истории сообщений
    pub async fn ask_with_context(&self, prompt: &str, history: &[String]) -> Result<String> {
        match &self.provider {
            AIProvider::Ollama { endpoint, model, .. } => {
                self.ask_ollama(endpoint, model, prompt, history).await
            }
            AIProvider::OpenRouter { api_key, model, endpoint } => {
                self.ask_openrouter(api_key, model, endpoint, prompt, history).await
            }
        }
    }

    /// Запрос к локальному Ollama
    async fn ask_ollama(
        &self,
        endpoint: &str,
        model: &str,
        prompt: &str,
        history: &[String],
    ) -> Result<String> {
        let context = self.format_context(history);
        let full_prompt = format!("{}\n\nВопрос пользователя: {}\n\nОтвечай кратко и по делу.", context, prompt);

        let res = self.client.post(endpoint)
            .json(&json!({
                "model": model,
                "prompt": full_prompt,
                "stream": false
            }))
            .send()
            .await
            .context("Ошибка подключения к Ollama")?;

        if !res.status().is_success() {
            anyhow::bail!("Ollama вернул ошибку: {}", res.status());
        }

        let value = res.json::<serde_json::Value>()
            .await
            .context("Ошибка парсинга ответа Ollama")?;

        if let Some(error) = value.get("error").and_then(|e| e.as_str()) {
            anyhow::bail!("Ошибка AI: {}", error);
        }

        Ok(value["response"]
            .as_str()
            .unwrap_or("Пустой ответ AI")
            .to_string())
    }

    /// Запрос к OpenRouter API
    async fn ask_openrouter(
        &self,
        api_key: &str,
        model: &str,
        endpoint: &str,
        prompt: &str,
        history: &[String],
    ) -> Result<String> {
        let messages = self.build_messages(prompt, history);

        let res = self.client.post(endpoint)
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .json(&json!({
                "model": model,
                "messages": messages,
                "max_tokens": 1024,
                "temperature": 0.7,
            }))
            .send()
            .await
            .context("Ошибка подключения к OpenRouter")?;

        if !res.status().is_success() {
            let status = res.status();
            let body = res.text().await.unwrap_or_default();
            anyhow::bail!("OpenRouter вернул ошибку ({}): {}", status, body);
        }

        let value = res.json::<serde_json::Value>()
            .await
            .context("Ошибка парсинга ответа OpenRouter")?;

        // Проверка на ошибки в ответе
        if let Some(error) = value.get("error").and_then(|e| e.as_str()) {
            anyhow::bail!("Ошибка AI: {}", error);
        }

        // Извлечение ответа из структуры OpenRouter
        let response = value["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("Пустой ответ AI");

        Ok(response.to_string())
    }

    /// Форматирование контекста истории
    fn format_context(&self, history: &[String]) -> String {
        if history.is_empty() {
            "Нет предыдущего контекста.".to_string()
        } else {
            format!("История последних сообщений:\n{}", history.join("\n"))
        }
    }

    /// Построение списка сообщений для OpenRouter
    fn build_messages(&self, prompt: &str, history: &[String]) -> Vec<serde_json::Value> {
        let mut messages = Vec::new();

        // Системное сообщение
        messages.push(json!({
            "role": "system",
            "content": "Ты — Liberty Architect, Senior Rust Engineer. Твоя специализация: разработка децентрализованного мессенджера Liberty Reach. Отвечай кратко и по делу."
        }));

        // История чата
        if !history.is_empty() {
            let context = self.format_context(history);
            messages.push(json!({
                "role": "user",
                "content": context
            }));
        }

        // Текущий вопрос
        messages.push(json!({
            "role": "user",
            "content": prompt
        }));

        messages
    }

    /// Анализ последних сообщений чата
    pub async fn analyze_chat(&self, messages: &[String], query: &str) -> Result<String> {
        if messages.is_empty() {
            return Ok("Нет сообщений для анализа.".to_string());
        }

        let analysis_prompt = format!(
            "Проанализируй следующие сообщения чата и ответь на вопрос.\n\n\
             Сообщения:\n{}\n\n\
             Вопрос: {}",
            messages.join("\n"),
            query
        );

        self.ask(&analysis_prompt).await
    }
}

impl Default for AIBridge {
    fn default() -> Self {
        Self::new()
    }
}
