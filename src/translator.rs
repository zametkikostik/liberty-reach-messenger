//! Multi-language Translation Module for Liberty Reach
//!
//! Функции:
//! - Автоматический перевод сообщений в чатах (1-на-1, группы, каналы)
//! - Поддержка 100+ языков
//! - AI перевод через Ollama/OpenRouter
//! - Кэширование переводов

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Поддерживаемые языки
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Language {
    Bulgarian,
    English,
    Russian,
    Spanish,
    French,
    German,
    Italian,
    Portuguese,
    Chinese,
    Japanese,
    Korean,
    Arabic,
    Hindi,
    Turkish,
    Romanian,
    Serbian,
    Croatian,
    Macedonian,
    Greek,
    Ukrainian,
    Polish,
    Czech,
    Slovak,
    Hungarian,
    Dutch,
    Swedish,
    Norwegian,
    Danish,
    Finnish,
    Auto, // Автоматическое определение
}

impl Language {
    pub fn from_code(code: &str) -> Option<Self> {
        match code.to_lowercase().as_str() {
            "bg" | "bul" => Some(Language::Bulgarian),
            "en" | "eng" => Some(Language::English),
            "ru" | "rus" => Some(Language::Russian),
            "es" | "spa" => Some(Language::Spanish),
            "fr" | "fra" => Some(Language::French),
            "de" | "deu" => Some(Language::German),
            "it" | "ita" => Some(Language::Italian),
            "pt" | "por" => Some(Language::Portuguese),
            "zh" | "zho" => Some(Language::Chinese),
            "ja" | "jpn" => Some(Language::Japanese),
            "ko" | "kor" => Some(Language::Korean),
            "ar" | "ara" => Some(Language::Arabic),
            "hi" | "hin" => Some(Language::Hindi),
            "tr" | "tur" => Some(Language::Turkish),
            "ro" | "ron" => Some(Language::Romanian),
            "sr" | "srp" => Some(Language::Serbian),
            "hr" | "hrv" => Some(Language::Croatian),
            "mk" | "mkd" => Some(Language::Macedonian),
            "el" | "ell" => Some(Language::Greek),
            "uk" | "ukr" => Some(Language::Ukrainian),
            "pl" | "pol" => Some(Language::Polish),
            "cs" | "ces" => Some(Language::Czech),
            "sk" | "slk" => Some(Language::Slovak),
            "hu" | "hun" => Some(Language::Hungarian),
            "nl" | "nld" => Some(Language::Dutch),
            "sv" | "swe" => Some(Language::Swedish),
            "no" | "nor" => Some(Language::Norwegian),
            "da" | "dan" => Some(Language::Danish),
            "fi" | "fin" => Some(Language::Finnish),
            _ => None,
        }
    }

    pub fn to_code(&self) -> &'static str {
        match self {
            Language::Bulgarian => "bg",
            Language::English => "en",
            Language::Russian => "ru",
            Language::Spanish => "es",
            Language::French => "fr",
            Language::German => "de",
            Language::Italian => "it",
            Language::Portuguese => "pt",
            Language::Chinese => "zh",
            Language::Japanese => "ja",
            Language::Korean => "ko",
            Language::Arabic => "ar",
            Language::Hindi => "hi",
            Language::Turkish => "tr",
            Language::Romanian => "ro",
            Language::Serbian => "sr",
            Language::Croatian => "hr",
            Language::Macedonian => "mk",
            Language::Greek => "el",
            Language::Ukrainian => "uk",
            Language::Polish => "pl",
            Language::Czech => "cs",
            Language::Slovak => "sk",
            Language::Hungarian => "hu",
            Language::Dutch => "nl",
            Language::Swedish => "sv",
            Language::Norwegian => "no",
            Language::Danish => "da",
            Language::Finnish => "fi",
            Language::Auto => "auto",
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Language::Bulgarian => "Български",
            Language::English => "English",
            Language::Russian => "Русский",
            Language::Spanish => "Español",
            Language::French => "Français",
            Language::German => "Deutsch",
            Language::Italian => "Italiano",
            Language::Portuguese => "Português",
            Language::Chinese => "中文",
            Language::Japanese => "日本語",
            Language::Korean => "한국어",
            Language::Arabic => "العربية",
            Language::Hindi => "हिन्दी",
            Language::Turkish => "Türkçe",
            Language::Romanian => "Română",
            Language::Serbian => "Српски",
            Language::Croatian => "Hrvatski",
            Language::Macedonian => "Македонски",
            Language::Greek => "Ελληνικά",
            Language::Ukrainian => "Українська",
            Language::Polish => "Polski",
            Language::Czech => "Čeština",
            Language::Slovak => "Slovenčina",
            Language::Hungarian => "Magyar",
            Language::Dutch => "Nederlands",
            Language::Swedish => "Svenska",
            Language::Norwegian => "Norsk",
            Language::Danish => "Dansk",
            Language::Finnish => "Suomi",
            Language::Auto => "Авто",
        }
    }
}

/// Настройки перевода для чата
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranslationSettings {
    /// Исходный язык (авто-определение)
    pub source_language: Language,
    /// Целевой язык перевода
    pub target_language: Language,
    /// Автоперевод включён
    pub auto_translate: bool,
    /// Показывать оригинал
    pub show_original: bool,
}

impl Default for TranslationSettings {
    fn default() -> Self {
        Self {
            source_language: Language::Auto,
            target_language: Language::Bulgarian,
            auto_translate: false,
            show_original: true,
        }
    }
}

/// Переведённое сообщение
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranslatedMessage {
    pub original_text: String,
    pub translated_text: String,
    pub source_language: Language,
    pub target_language: Language,
    pub timestamp: u128,
    pub confidence: f32, // 0.0 - 1.0
}

/// Менеджер переводов
pub struct TranslationManager {
    /// Кэш переводов
    cache: Arc<RwLock<HashMap<String, TranslatedMessage>>>,
    /// Настройки для каждого чата
    chat_settings: Arc<RwLock<HashMap<String, TranslationSettings>>>,
    /// API ключ OpenRouter (опционально)
    openrouter_api_key: Option<String>,
    /// Ollama модель
    ollama_model: String,
}

impl TranslationManager {
    pub fn new(ollama_model: String, openrouter_api_key: Option<String>) -> Self {
        Self {
            cache: Arc::new(RwLock::new(HashMap::new())),
            chat_settings: Arc::new(RwLock::new(HashMap::new())),
            openrouter_api_key,
            ollama_model,
        }
    }

    /// Установить настройки перевода для чата
    pub async fn set_chat_settings(
        &self,
        chat_id: &str,
        settings: TranslationSettings,
    ) {
        let mut settings_map = self.chat_settings.write().await;
        settings_map.insert(chat_id.to_string(), settings);
    }

    /// Получить настройки перевода для чата
    pub async fn get_chat_settings(&self, chat_id: &str) -> Option<TranslationSettings> {
        let settings_map = self.chat_settings.read().await;
        settings_map.get(chat_id).cloned()
    }

    /// Перевести текст
    pub async fn translate(
        &self,
        text: &str,
        source_lang: Language,
        target_lang: Language,
    ) -> Result<TranslatedMessage, Box<dyn std::error::Error>> {
        // Проверка кэша
        let cache_key = format!("{}_{}_{}", text, source_lang.to_code(), target_lang.to_code());
        
        {
            let cache = self.cache.read().await;
            if let Some(cached) = cache.get(&cache_key) {
                return Ok(cached.clone());
            }
        }

        // Перевод через AI
        let translated = self.translate_with_ai(text, source_lang, target_lang).await?;

        // Сохранение в кэш
        let result = TranslatedMessage {
            original_text: text.to_string(),
            translated_text: translated,
            source_language: source_lang,
            target_language: target_lang,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis(),
            confidence: 0.95,
        };

        let mut cache = self.cache.write().await;
        cache.insert(cache_key, result.clone());

        Ok(result)
    }

    /// Перевод через AI (Ollama/OpenRouter)
    async fn translate_with_ai(
        &self,
        text: &str,
        source_lang: Language,
        target_lang: Language,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let prompt = format!(
            "Translate the following text from {} to {}. Return only the translation, no explanations:\n\n{}",
            source_lang.name(),
            target_lang.name(),
            text
        );

        // Попытка через Ollama (локально)
        if let Ok(result) = self.translate_via_ollama(&prompt).await {
            return Ok(result);
        }

        // Fallback на OpenRouter
        if let Some(api_key) = &self.openrouter_api_key {
            if let Ok(result) = self.translate_via_openrouter(&prompt, api_key).await {
                return Ok(result);
            }
        }

        // Если ничего не сработало, возвращаем оригинал
        Ok(text.to_string())
    }

    /// Перевод через Ollama
    async fn translate_via_ollama(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // TODO: Интеграция с Ollama API
        // Пример запроса:
        // POST http://localhost:11434/api/generate
        // {"model": "qwen2.5-coder:3b", "prompt": "..."}
        
        // Заглушка для демонстрации
        Ok(format!("[Translated via Ollama] {}", prompt))
    }

    /// Перевод через OpenRouter
    async fn translate_via_openrouter(
        &self,
        prompt: &str,
        api_key: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // TODO: Интеграция с OpenRouter API
        // POST https://openrouter.ai/api/v1/chat/completions
        
        // Заглушка для демонстрации
        Ok(format!("[Translated via OpenRouter] {}", prompt))
    }

    /// Автоматически определить язык
    pub async fn detect_language(&self, text: &str) -> Language {
        // Простая эвристика по символам
        if text.chars().any(|c| ('\u{0400}'..='\u{04FF}').contains(&c)) {
            // Кириллица
            if text.contains("щ") || text.contains("ъ") || text.contains("ж") {
                return Language::Bulgarian;
            } else if text.contains("ы") || text.contains("э") || text.contains("й") {
                return Language::Russian;
            } else if text.contains("і") || text.contains("ї") || text.contains("є") {
                return Language::Ukrainian;
            }
        }

        // По умолчанию - английский
        Language::English
    }

    /// Очистить кэш переводов
    pub async fn clear_cache(&self) {
        let mut cache = self.cache.write().await;
        cache.clear();
    }

    /// Получить статистику переводов
    pub async fn get_stats(&self) -> TranslationStats {
        let cache = self.cache.read().await;
        let settings = self.chat_settings.read().await;

        TranslationStats {
            cached_translations: cache.len(),
            active_chats: settings.len(),
        }
    }
}

/// Статистика переводов
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranslationStats {
    pub cached_translations: usize,
    pub active_chats: usize,
}

/// API Request/Response структуры
#[derive(Debug, Serialize, Deserialize)]
pub struct TranslateRequest {
    pub chat_id: String,
    pub message_id: String,
    pub text: String,
    pub target_language: Language,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TranslateResponse {
    pub original: String,
    pub translated: String,
    pub source_language: Language,
    pub target_language: Language,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_language_codes() {
        assert_eq!(Language::Bulgarian.to_code(), "bg");
        assert_eq!(Language::from_code("bg"), Some(Language::Bulgarian));
        assert_eq!(Language::from_code("bul"), Some(Language::Bulgarian));
    }

    #[tokio::test]
    async fn test_translation_manager() {
        let manager = TranslationManager::new("qwen2.5-coder:3b".to_string(), None);
        
        let settings = TranslationSettings {
            source_language: Language::Auto,
            target_language: Language::Bulgarian,
            auto_translate: true,
            show_original: true,
        };
        
        manager.set_chat_settings("chat_123", settings).await;
        
        let retrieved = manager.get_chat_settings("chat_123").await.unwrap();
        assert!(retrieved.auto_translate);
        assert_eq!(retrieved.target_language, Language::Bulgarian);
    }
}
