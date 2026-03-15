//! AI Guard - Опциональная AI-модерация с уважением к приватности
//!
//! Этот модуль предоставляет:
//! - Опциональную AI-модерацию через OpenRouter API
//! - Локальное кэширование результатов
//! - Систему "mute" для нарушителей
//! - Полную приватность - модерация только если пользователь включил
//!
//! # Безопасность
//! - AI ключ хранится в .env, не в коде
//! - Модерация работает только для публичных чатов
//! - Семейный круг (EncryptedCircle) всегда полностью приватный

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sled::Db;
use std::collections::HashMap;
use std::error::Error;
use std::sync::Arc;
use tokio::sync::RwLock;

/// OpenRouter API endpoint
const OPENROUTER_API_URL: &str = "https://openrouter.ai/api/v1/chat/completions";

/// Модель для анализа (бесплатная и быстрая)
const AI_MODEL: &str = "meta-llama/llama-3-8b-instruct";

/// Результат AI анализа
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiAnalysisResult {
    /// Сообщение безопасно
    pub safe: bool,
    /// Причина блокировки (если есть)
    pub reason: Option<String>,
    /// Уровень токсичности (0.0 - 1.0)
    pub toxicity_score: f32,
}

/// Нарушение правил
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ViolationType {
    Discrimination,
    HateSpeech,
    Scam,
    Recruitment,
    Violence,
    Other,
}

/// Запись о нарушении
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViolationRecord {
    pub peer_id: String,
    pub violation_type: ViolationType,
    pub timestamp: DateTime<Utc>,
    pub reason: String,
}

/// Информация о mute пользователя
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MuteInfo {
    pub peer_id: String,
    pub muted_until: DateTime<Utc>,
    pub violation_count: u32,
}

/// Конфигурация AI Guard
#[derive(Clone)]
pub struct AiGuardConfig {
    /// API ключ OpenRouter
    pub api_key: Option<String>,
    /// Включить модерацию (пользователь может выключить)
    pub enabled: bool,
    /// Порог токсичности для блокировки (0.0 - 1.0)
    pub toxicity_threshold: f32,
    /// Количество нарушений до mute
    pub mute_threshold: u32,
    /// Длительность mute
    pub mute_duration_hours: i64,
}

impl AiGuardConfig {
    /// Создать конфигурацию из переменных окружения
    pub fn from_env() -> Self {
        let api_key = std::env::var("OPENROUTER_API_KEY").ok();
        let enabled = api_key.is_some();

        Self {
            api_key,
            enabled,
            toxicity_threshold: 0.7,
            mute_threshold: 3,
            mute_duration_hours: 1,
        }
    }

    /// Включена ли модерация
    pub fn is_enabled(&self) -> bool {
        self.enabled && self.api_key.is_some()
    }
}

/// AI Guard - модератор сообщений
pub struct AiGuard {
    pub config: AiGuardConfig,
    db: Arc<RwLock<Db>>,
    /// Кэш результатов анализа (чтобы не запрашивать API повторно)
    /// Кэш результатов анализа (чтобы не запрашивать API повторно)
    pub cache: RwLock<HashMap<String, AiAnalysisResult>>,
    /// HTTP клиент
    http_client: reqwest::Client,
}

impl AiGuard {
    /// Создать новый AI Guard
    pub fn new(config: AiGuardConfig, db: Arc<RwLock<Db>>) -> Self {
        Self {
            config,
            db,
            cache: RwLock::new(HashMap::new()),
            http_client: reqwest::Client::new(),
        }
    }

    /// Анализировать текст на наличие нарушений
    pub async fn analyze_content(&self, text: &str) -> Result<AiAnalysisResult, Box<dyn Error>> {
        // Проверяем кэш
        {
            let cache = self.cache.read().await;
            if let Some(result) = cache.get(text) {
                return Ok(result.clone());
            }
        }

        // Если модерация выключена - пропускаем всё
        if !self.config.is_enabled() {
            return Ok(AiAnalysisResult {
                safe: true,
                reason: None,
                toxicity_score: 0.0,
            });
        }

        // Запрашиваем анализ у OpenRouter
        let result = self.call_openrouter(text).await?;

        // Кэшируем результат
        {
            let mut cache = self.cache.write().await;
            cache.insert(text.to_string(), result.clone());
        }

        Ok(result)
    }

    /// Вызов OpenRouter API
    async fn call_openrouter(&self, text: &str) -> Result<AiAnalysisResult, Box<dyn Error>> {
        let api_key = self.config.api_key.as_ref()
            .ok_or("OpenRouter API key not configured")?;

        // Системный промпт
        let system_prompt = r#"Ты — офицер безопасности Liberty Reach мессенджера.
Анализируй текст на предмет:
- Дискриминации по расе, полу, религии
- Призывов к насилию
- Мошенничества и скама
- Вербовки в незаконные организации

Ответь ТОЛЬКО в формате JSON:
{
  "safe": true/false,
  "reason": "причина если unsafe" или null,
  "toxicity_score": 0.0-1.0
}"#;

        // Запрос к API
        let request_body = serde_json::json!({
            "model": AI_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text}
            ],
            "temperature": 0.1,
            "max_tokens": 100
        });

        let response = self.http_client
            .post(OPENROUTER_API_URL)
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .json(&request_body)
            .send()
            .await?;

        if !response.status().is_success() {
            // Если API недоступен - пропускаем сообщение (fail-open)
            eprintln!("⚠️ [AI Guard] OpenRouter API error: {}", response.status());
            return Ok(AiAnalysisResult {
                safe: true,
                reason: Some("AI service unavailable".to_string()),
                toxicity_score: 0.0,
            });
        }

        let api_response: OpenRouterResponse = response.json().await?;

        // Парсим ответ
        let content = api_response.choices
            .first()
            .and_then(|c| c.message.content.as_ref())
            .ok_or("Empty response from AI")?;

        // Извлекаем JSON из ответа
        let json_start = content.find('{').unwrap_or(0);
        let json_end = content.rfind('}').unwrap_or(content.len());
        let json_str = &content[json_start..=json_end];

        let analysis: AiAnalysisResult = serde_json::from_str(json_str)
            .unwrap_or_else(|_| AiAnalysisResult {
                safe: true,
                reason: Some("Parse error".to_string()),
                toxicity_score: 0.0,
            });

        Ok(analysis)
    }

    /// Проверить, может ли пользователь отправлять сообщения
    pub async fn can_send_message(&self, peer_id: &str) -> Result<bool, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("ai_guard")?;

        if let Some(mute_bytes) = tree.get(format!("mute_{}", peer_id).as_bytes())? {
            let mute_info: MuteInfo = serde_json::from_slice(&mute_bytes)?;

            if Utc::now() < mute_info.muted_until {
                return Ok(false); // Всё ещё в mute
            }

            // Mute истёк - удаляем запись
            tree.remove(format!("mute_{}", peer_id).as_bytes())?;
        }

        Ok(true)
    }

    /// Записать нарушение
    pub async fn record_violation(
        &self,
        peer_id: &str,
        violation_type: ViolationType,
        reason: &str,
    ) -> Result<(), Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("ai_guard")?;

        // Получаем текущее количество нарушений
        let violations_key = format!("violations_{}", peer_id);
        let count = if let Some(count_bytes) = tree.get(violations_key.as_bytes())? {
            let count: u32 = serde_json::from_slice(&count_bytes)?;
            count + 1
        } else {
            1
        };

        // Сохраняем новое количество
        tree.insert(
            violations_key.as_bytes(),
            serde_json::to_vec(&count)?,
        )?;

        // Сохраняем запись о нарушении
        let violation = ViolationRecord {
            peer_id: peer_id.to_string(),
            violation_type,
            timestamp: Utc::now(),
            reason: reason.to_string(),
        };

        let violation_key = format!("violation_{}_{}", peer_id, Utc::now().timestamp());
        tree.insert(violation_key.as_bytes(), serde_json::to_vec(&violation)?)?;

        // Проверяем, нужно ли наложить mute
        if count >= self.config.mute_threshold {
            let mute_info = MuteInfo {
                peer_id: peer_id.to_string(),
                muted_until: Utc::now() + Duration::hours(self.config.mute_duration_hours),
                violation_count: count,
            };

            tree.insert(
                format!("mute_{}", peer_id).as_bytes(),
                serde_json::to_vec(&mute_info)?,
            )?;

            println!("🔇 [AI Guard] Пользователь {} заблокирован на {} час(ов)",
                peer_id, self.config.mute_duration_hours);
        }

        tree.flush()?;

        Ok(())
    }

    /// Получить информацию о нарушениях пользователя
    pub async fn get_violations(&self, peer_id: &str) -> Result<Vec<ViolationRecord>, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("ai_guard")?;

        let mut violations = Vec::new();

        let prefix = format!("violation_{}_", peer_id);
        for entry in tree.scan_prefix(prefix.as_bytes()) {
            if let Ok((_, value)) = entry {
                if let Ok(violation) = serde_json::from_slice::<ViolationRecord>(&value) {
                    violations.push(violation);
                }
            }
        }

        violations.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

        Ok(violations)
    }

    /// Сбросить нарушения пользователя (для админа)
    pub async fn reset_violations(&self, peer_id: &str) -> Result<(), Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("ai_guard")?;

        // Удаляем все нарушения
        let prefix = format!("violation_{}_", peer_id);
        let mut keys_to_remove = Vec::new();

        for entry in tree.scan_prefix(prefix.as_bytes()) {
            if let Ok((key, _)) = entry {
                keys_to_remove.push(key.to_vec());
            }
        }

        for key in keys_to_remove {
            tree.remove(&key)?;
        }

        // Удаляем mute
        tree.remove(format!("mute_{}", peer_id).as_bytes())?;
        tree.remove(format!("violations_{}", peer_id).as_bytes())?;

        tree.flush()?;

        Ok(())
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

/// EncryptedCircle - приватный круг для доверенных контактов
/// Сообщения шифруются перед отправкой в Gossipsub
pub struct EncryptedCircle {
    /// PeerID владельца
    owner_peer_id: String,
    /// PeerID участников круга
    members: Vec<String>,
    /// Общий секретный ключ (выведенный из PeerID участников)
    shared_secret: [u8; 32],
}

impl EncryptedCircle {
    /// Создать новый круг с другим участником
    pub fn new(owner_peer_id: String, member_peer_id: String, static_secret: &[u8; 32]) -> Self {
        // Создаём общий секрет из статического ключа и PeerID участников
        use sha2::{Sha256, Digest};

        let mut hasher = Sha256::new();
        hasher.update(static_secret);
        hasher.update(&owner_peer_id);
        hasher.update(&member_peer_id);

        let shared_secret = hasher.finalize().into();

        Self {
            owner_peer_id,
            members: vec![member_peer_id],
            shared_secret,
        }
    }

    /// Зашифровать сообщение для круга
    pub fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>, Box<dyn Error>> {
        use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce};
        use rand::rngs::OsRng;
        use rand::RngCore;
        use aead::{Aead, Key};

        let cipher = ChaCha20Poly1305::new(Key::<ChaCha20Poly1305>::from_slice(&self.shared_secret));

        // Генерируем случайную nonce
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        // Шифруем
        let ciphertext = cipher.encrypt(nonce, plaintext).map_err(|e| format!("Encryption error: {}", e))?;

        // Возвращаем nonce + ciphertext
        let mut result = Vec::with_capacity(12 + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);

        Ok(result)
    }

    /// Расшифровать сообщение из круга
    pub fn decrypt(&self, encrypted: &[u8]) -> Result<Vec<u8>, Box<dyn Error>> {
        use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce};
        use aead::{Aead, Key};

        if encrypted.len() < 12 {
            return Err("Invalid ciphertext length".into());
        }

        let cipher = ChaCha20Poly1305::new(Key::<ChaCha20Poly1305>::from_slice(&self.shared_secret));

        let nonce = Nonce::from_slice(&encrypted[..12]);
        let ciphertext = &encrypted[12..];

        let plaintext = cipher.decrypt(nonce, ciphertext).map_err(|e| format!("Decryption error: {}", e))?;

        Ok(plaintext)
    }

    /// Добавить участника в круг
    pub fn add_member(&mut self, peer_id: String) {
        if !self.members.contains(&peer_id) {
            self.members.push(peer_id);
        }
    }

    /// Получить уникальный topic для круга
    pub fn get_topic(&self) -> String {
        use sha2::{Sha256, Digest};

        let mut hasher = Sha256::new();
        hasher.update(&self.owner_peer_id);
        for member in &self.members {
            hasher.update(member);
        }

        let hash = hasher.finalize();
        format!("liberty-circle-{}", hex::encode(&hash[..8]))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypted_circle() {
        let owner = "owner_peer_id".to_string();
        let member = "member_peer_id".to_string();
        let static_secret = [1u8; 32];

        let circle = EncryptedCircle::new(owner, member, &static_secret);

        let plaintext = b"Hello, private circle!";
        let encrypted = circle.encrypt(plaintext).unwrap();
        let decrypted = circle.decrypt(&encrypted).unwrap();

        assert_eq!(plaintext.to_vec(), decrypted);
        assert_ne!(plaintext.to_vec(), encrypted);
    }

    #[test]
    fn test_circle_topic() {
        let owner = "owner".to_string();
        let member = "member".to_string();
        let static_secret = [1u8; 32];

        let circle = EncryptedCircle::new(owner.clone(), member.clone(), &static_secret);
        let topic = circle.get_topic();

        assert!(topic.starts_with("liberty-circle-"));
        assert_eq!(topic.len(), 30); // "liberty-circle-" + 16 hex chars
    }
}
