//! Гибридная модерация: Локальная + OpenRouter (опционально)
//!
//! Приоритет:
//! 1. Локальная модерация (быстрая, бесплатная)
//! 2. OpenRouter AI (если есть кредиты)

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sled::Db;
use std::collections::HashSet;
use std::error::Error;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Конфигурация гибридной модерации
#[derive(Clone)]
pub struct HybridModerationConfig {
    /// Включить локальную модерацию
    pub local_enabled: bool,
    /// OpenRouter API ключ (опционально)
    pub openrouter_key: Option<String>,
    /// Порог токсичности для AI (0.0 - 1.0)
    pub ai_threshold: f32,
}

impl HybridModerationConfig {
    pub fn from_env() -> Self {
        let openrouter_key = std::env::var("OPENROUTER_API_KEY").ok();
        
        Self {
            local_enabled: true, // Локальная всегда включена
            openrouter_key,
            ai_threshold: 0.7,
        }
    }
}

/// Локальные правила модерации
pub struct LocalModeration {
    /// Запрещённые слова
    blacklist: HashSet<String>,
    /// Спам лимит (сообщений в секунду)
    spam_limit: u32,
    /// Чёрный список доменов
    domain_blacklist: HashSet<String>,
}

impl LocalModeration {
    pub fn new() -> Self {
        let mut blacklist = HashSet::new();
        
        // Русские запрещённые слова
        blacklist.extend([
            "доллар", "инвест", "крипта", "биткоин", "переведи",
            "заработок", "доход", "прибыль", "вложи", "гарантия",
            "умри", "смерть", "убей", "насилие", "террор",
            "наркотик", "продам", "куплю", "оружие",
        ].iter().map(|s| s.to_lowercase()));
        
        // Английские запрещённые слова
        blacklist.extend([
            "crypto", "invest", "bitcoin", "ethereum", "transfer",
            "earn", "profit", "guarantee", "die", "kill",
            "terror", "drug", "sell", "buy", "weapon",
        ].iter().map(|s| s.to_lowercase()));
        
        let mut domain_blacklist = HashSet::new();
        domain_blacklist.extend([
            "bit.ly", "tinyurl.com", "t.me/+invite",
        ].iter().map(|s| s.to_string()));
        
        Self {
            blacklist,
            spam_limit: 3,
            domain_blacklist,
        }
    }
    
    /// Проверить текст локальными правилами
    pub fn check(&self, text: &str) -> ModerationResult {
        let text_lower = text.to_lowercase();
        
        // Проверка запрещённых слов
        for word in &self.blacklist {
            if text_lower.contains(word) {
                return ModerationResult {
                    safe: false,
                    reason: Some(format!("Local filter: forbidden word '{}'", word)),
                    toxicity_score: 0.8,
                    source: "local",
                };
            }
        }
        
        // Проверка доменов
        for domain in &self.domain_blacklist {
            if text.contains(domain) {
                return ModerationResult {
                    safe: false,
                    reason: Some(format!("Local filter: blocked domain '{}'", domain)),
                    toxicity_score: 0.7,
                    source: "local",
                };
            }
        }
        
        // Проверка на спам (повторы)
        let words: Vec<&str> = text.split_whitespace().collect();
        if words.len() > 20 {
            let unique_ratio = words.iter()
                .collect::<HashSet<_>>()
                .len() as f32 / words.len() as f32;
            
            if unique_ratio < 0.3 {
                return ModerationResult {
                    safe: false,
                    reason: Some("Local filter: spam detected (low unique ratio)".to_string()),
                    toxicity_score: 0.6,
                    source: "local",
                };
            }
        }
        
        // Всё чисто
        ModerationResult {
            safe: true,
            reason: None,
            toxicity_score: 0.0,
            source: "local",
        }
    }
}

/// Результат модерации
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModerationResult {
    pub safe: bool,
    pub reason: Option<String>,
    pub toxicity_score: f32,
    pub source: &'static str, // "local" или "ai"
}

/// Гибридный модератор
pub struct HybridModerator {
    config: HybridModerationConfig,
    local: LocalModeration,
    db: Arc<RwLock<Db>>,
    http_client: reqwest::Client,
}

impl HybridModerator {
    pub fn new(config: HybridModerationConfig, db: Arc<RwLock<Db>>) -> Self {
        Self {
            config,
            local: LocalModeration::new(),
            db,
            http_client: reqwest::Client::new(),
        }
    }
    
    /// Проверить контент (гибридный режим)
    pub async fn moderate(&self, text: &str) -> Result<ModerationResult, Box<dyn Error>> {
        // 1. Локальная проверка (всегда)
        let local_result = self.local.check(text);
        
        if !local_result.safe {
            // Локальная модерация заблокировала
            return Ok(local_result);
        }
        
        // 2. AI проверка (если есть ключ)
        if let Some(ref api_key) = self.config.openrouter_key {
            match self.check_with_ai(api_key, text).await {
                Ok(ai_result) => {
                    if !ai_result.safe {
                        return Ok(ai_result);
                    }
                }
                Err(e) => {
                    eprintln!("⚠️ [HybridModerator] AI error: {}", e);
                    // Продолжаем с локальным результатом (fail-open)
                }
            }
        }
        
        // Всё чисто
        Ok(local_result)
    }
    
    /// Проверка через OpenRouter AI
    async fn check_with_ai(&self, api_key: &str, text: &str) -> Result<ModerationResult, Box<dyn Error>> {
        let system_prompt = r#"Ты — офицер безопасности Liberty Reach.
Анализируй текст на предмет:
- Дискриминации по расе, полу, религии
- Призывов к насилию
- Мошенничества и скама
- Вербовки в незаконные организации

Ответь ТОЛЬКО в формате JSON:
{"safe": true/false, "reason": "причина" или null, "toxicity_score": 0.0-1.0}"#;

        let request_body = serde_json::json!({
            "model": "meta-llama/llama-3-8b-instruct",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text}
            ],
            "temperature": 0.1,
            "max_tokens": 100
        });

        let response = self.http_client
            .post("https://openrouter.ai/api/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .header("HTTP-Referer", "https://liberty-reach.local")
            .json(&request_body)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(format!("OpenRouter API error: {}", error_text).into());
        }

        let api_response: OpenRouterResponse = response.json().await?;
        
        let content = api_response.choices
            .first()
            .and_then(|c| c.message.content.as_ref())
            .ok_or("Empty response from AI")?;

        // Извлекаем JSON из ответа
        let json_start = content.find('{').unwrap_or(0);
        let json_end = content.rfind('}').unwrap_or(content.len());
        let json_str = &content[json_start..=json_end];

        let ai_result: AiAnalysisResult = serde_json::from_str(json_str)
            .unwrap_or(AiAnalysisResult {
                safe: true,
                reason: Some("AI parse error".to_string()),
                toxicity_score: 0.0,
            });

        Ok(ModerationResult {
            safe: ai_result.safe,
            reason: ai_result.reason,
            toxicity_score: ai_result.toxicity_score,
            source: "ai",
        })
    }
}

/// Ответ от OpenRouter API
#[derive(Debug, Deserialize)]
struct OpenRouterResponse {
    choices: Vec<Choice>,
}

#[derive(Debug, Deserialize)]
struct Choice {
    message: Message,
}

#[derive(Debug, Deserialize)]
struct Message {
    content: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AiAnalysisResult {
    safe: bool,
    reason: Option<String>,
    toxicity_score: f32,
}

/// Нарушение правил
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViolationRecord {
    pub peer_id: String,
    pub timestamp: DateTime<Utc>,
    pub reason: String,
    pub source: String, // "local" или "ai"
}

/// Информация о mute
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MuteInfo {
    pub peer_id: String,
    pub muted_until: DateTime<Utc>,
    pub violation_count: u32,
}

impl HybridModerator {
    /// Проверить, может ли пользователь отправлять сообщения
    pub async fn can_send(&self, peer_id: &str) -> Result<bool, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("moderation")?;

        if let Some(mute_bytes) = tree.get(format!("mute_{}", peer_id).as_bytes())? {
            let mute_info: MuteInfo = serde_json::from_slice(&mute_bytes)?;
            
            if Utc::now() < mute_info.muted_until {
                return Ok(false);
            }
            
            // Mute истёк - удаляем
            tree.remove(format!("mute_{}", peer_id).as_bytes())?;
        }

        Ok(true)
    }

    /// Записать нарушение
    pub async fn record_violation(
        &self,
        peer_id: &str,
        reason: &str,
        source: &str,
    ) -> Result<(), Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("moderation")?;

        // Получаем количество нарушений
        let violations_key = format!("violations_{}", peer_id);
        let count = if let Some(count_bytes) = tree.get(violations_key.as_bytes())? {
            let count: u32 = serde_json::from_slice(&count_bytes)?;
            count + 1
        } else {
            1
        };

        tree.insert(violations_key.as_bytes(), serde_json::to_vec(&count)?)?;

        // Сохраняем нарушение
        let violation = ViolationRecord {
            peer_id: peer_id.to_string(),
            timestamp: Utc::now(),
            reason: reason.to_string(),
            source: source.to_string(),
        };

        let key = format!("violation_{}_{}", peer_id, Utc::now().timestamp());
        tree.insert(key.as_bytes(), serde_json::to_vec(&violation)?)?;

        // Mute если 3+ нарушений
        if count >= 3 {
            let mute_info = MuteInfo {
                peer_id: peer_id.to_string(),
                muted_until: Utc::now() + Duration::hours(1),
                violation_count: count,
            };

            tree.insert(format!("mute_{}", peer_id).as_bytes(), serde_json::to_vec(&mute_info)?)?;
            println!("🔇 [Moderator] Пользователь {} заблокирован на 1 час", peer_id);
        }

        tree.flush()?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_local_moderation() {
        let moderator = LocalModeration::new();

        // Нормальное сообщение
        let result = moderator.check("Привет! Как дела?");
        assert!(result.safe);

        // Запрещённое слово
        let result = moderator.check("Купи биткоин сейчас!");
        assert!(!result.safe);

        // Спам
        let spam = "лох лох лох лох лох лох лох лох лох лох лох лох";
        let result = moderator.check(spam);
        assert!(!result.safe);
    }
}
