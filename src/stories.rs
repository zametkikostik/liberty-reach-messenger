//! Децентрализованные Stories (Истории)
//!
//! Этот модуль предоставляет функциональность для создания и распространения
//! ephemeral-контента (историй) через IPFS и Gossipsub.
//!
//! Особенности:
//! - Загрузка изображений в Pinata IPFS
//! - Вещание CID через Gossipsub topic "liberty-stories"
//! - Авто-очистка_expired_ историй из локальной БД

use chrono::{DateTime, Duration, Utc};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use serde::{Deserialize, Serialize};
use sled::Db;
use std::error::Error;
use std::sync::Arc;
use tokio::sync::RwLock;

type HmacSha256 = Hmac<Sha256>;

/// Структура элемента истории
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct StoryItem {
    /// IPFS Content ID (CID) загруженного медиа
    pub cid: String,
    /// PeerID автора истории
    pub author_peer_id: String,
    /// Временная метка создания
    pub timestamp: DateTime<Utc>,
    /// Время истечения (24 часа от создания)
    pub expires_at: DateTime<Utc>,
    /// Опциональное описание/текст
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub caption: Option<String>,
    /// Тип контента (image, video, etc.)
    #[serde(default = "default_content_type")]
    pub content_type: String,
}

fn default_content_type() -> String {
    "image".to_string()
}

impl StoryItem {
    /// Создать новую историю с автоматическим временем истечения
    pub fn new(author_peer_id: String, cid: String, caption: Option<String>) -> Self {
        let now = Utc::now();
        let expires_at = now + Duration::hours(24);

        Self {
            cid,
            author_peer_id,
            timestamp: now,
            expires_at,
            caption,
            content_type: "image".to_string(),
        }
    }

    /// Проверка, истекла ли история
    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }

    /// Оставшееся время в секундах до истечения
    pub fn time_remaining(&self) -> i64 {
        (self.expires_at - Utc::now()).num_seconds().max(0)
    }
}

/// Сообщение для Gossipsub broadcast
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct StoryBroadcast {
    /// CID контента
    pub cid: String,
    /// PeerID автора
    pub author_peer_id: String,
    /// Временная метка
    pub timestamp: DateTime<Utc>,
    /// Хеш для верификации целостности
    pub signature: String,
}

impl StoryBroadcast {
    pub fn new(cid: String, author_peer_id: String, signature: String) -> Self {
        Self {
            cid,
            author_peer_id,
            timestamp: Utc::now(),
            signature,
        }
    }
}

/// Конфигурация Pinata API
#[derive(Clone, Debug)]
pub struct PinataConfig {
    pub api_key: String,
    pub secret_key: String,
    pub jwt_token: Option<String>,
}

impl PinataConfig {
    pub fn new(api_key: String, secret_key: String, jwt_token: Option<String>) -> Self {
        Self {
            api_key,
            secret_key,
            jwt_token,
        }
    }
    
    /// Создать конфигурацию только с JWT токеном (рекомендуется)
    pub fn from_jwt(jwt_token: String) -> Self {
        Self {
            api_key: String::new(),
            secret_key: String::new(),
            jwt_token: Some(jwt_token),
        }
    }
}

/// Клиент для работы с Pinata IPFS
pub struct PinataClient {
    config: PinataConfig,
    http_client: reqwest::Client,
}

impl PinataClient {
    /// Создать новый PinataClient
    pub fn new(config: PinataConfig) -> Self {
        let http_client = reqwest::Client::new();
        Self { config, http_client }
    }

    /// Загрузить файл (изображение) в Pinata IPFS
    /// 
    /// # Аргументы
    /// * `file_bytes` - байты файла
    /// * `filename` - имя файла
    /// 
    /// # Возвращает
    /// CID загруженного файла
    pub async fn upload_image(&self, file_bytes: Vec<u8>, filename: &str) -> Result<String, Box<dyn Error>> {
        // Создаём multipart форму
        let form = reqwest::multipart::Form::new()
            .part("file", reqwest::multipart::Part::bytes(file_bytes).file_name(filename.to_string()));

        // Создаём JWT для аутентификации
        let jwt = self.create_jwt()?;

        let response = self.http_client
            .post("https://api.pinata.cloud/pinning/pinFileToIPFS")
            .header("Authorization", format!("Bearer {}", jwt))
            .multipart(form)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await?;
            return Err(format!("Pinata API error {}: {}", status, error_text).into());
        }

        let result: PinataUploadResponse = response.json().await?;
        Ok(result.IpfsHash)
    }

    /// Создать JWT токен для аутентификации в Pinata
    fn create_jwt(&self) -> Result<String, Box<dyn Error>> {
        // Если JWT токен уже предоставлен - используем его
        if let Some(ref jwt) = self.config.jwt_token {
            return Ok(jwt.clone());
        }
        
        // Иначе генерируем из API ключей (устаревший метод)
        use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
        use chrono::Utc;

        let header = serde_json::json!({"alg": "HS256", "typ": "JWT"});
        let header_encoded = URL_SAFE_NO_PAD.encode(serde_json::to_string(&header)?.as_bytes());

        let now = Utc::now().timestamp();
        let exp = now + 86400;
        let payload = serde_json::json!({"iss": self.config.api_key, "exp": exp});
        let payload_encoded = URL_SAFE_NO_PAD.encode(serde_json::to_string(&payload)?.as_bytes());

        let mut mac = HmacSha256::new_from_slice(self.config.secret_key.as_bytes())?;
        mac.update(format!("{}.{}", header_encoded, payload_encoded).as_bytes());
        let signature = mac.finalize().into_bytes();
        let signature_encoded = URL_SAFE_NO_PAD.encode(&signature);

        Ok(format!("{}.{}.{}", header_encoded, payload_encoded, signature_encoded))
    }

    /// Получить метаданные файла по CID
    pub async fn get_metadata(&self, cid: &str) -> Result<PinataMetadata, Box<dyn Error>> {
        let jwt = self.create_jwt()?;

        let response = self.http_client
            .get(format!("https://api.pinata.cloud/data/pinList?hash={}", cid))
            .header("Authorization", format!("Bearer {}", jwt))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("Pinata API error: {}", response.status()).into());
        }

        let result: PinataMetadataResponse = response.json().await?;
        Ok(result.data.first().cloned().unwrap_or_default())
    }

    /// Удалить (unpin) файл из Pinata по CID
    pub async fn unpin(&self, cid: &str) -> Result<(), Box<dyn Error>> {
        let jwt = self.create_jwt()?;

        let response = self.http_client
            .delete(format!("https://api.pinata.cloud/pinning/{}", cid))
            .header("Authorization", format!("Bearer {}", jwt))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("Pinata unpin error: {}", response.status()).into());
        }

        Ok(())
    }
}

/// Ответ от Pinata API при загрузке
#[derive(Serialize, Deserialize, Debug)]
struct PinataUploadResponse {
    IpfsHash: String,
    PinSize: u64,
    Timestamp: String,
}

/// Метаданные из Pinata
#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct PinataMetadata {
    pub id: u64,
    pub ipfs_hash: String,
    pub size: u64,
    pub user_id: String,
    pub date_pinned: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct PinataMetadataResponse {
    data: Vec<PinataMetadata>,
    count: usize,
}

/// Менеджер историй
#[derive(Clone)]
pub struct StoryManager {
    db: Arc<RwLock<Db>>,
    pinata_client: Option<Arc<PinataClient>>,
    local_peer_id: String,
}

impl StoryManager {
    /// Создать новый StoryManager
    pub fn new(db: Arc<RwLock<Db>>, local_peer_id: String) -> Self {
        Self {
            db,
            pinata_client: None,
            local_peer_id,
        }
    }

    /// Установить Pinata клиент
    pub fn set_pinata_client(&mut self, config: PinataConfig) {
        self.pinata_client = Some(Arc::new(PinataClient::new(config)));
    }

    /// Сохранить историю в локальную БД
    pub async fn save_story(&self, story: &StoryItem) -> Result<(), Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("stories")?;

        let key = format!("story_{}_{}", story.author_peer_id, story.timestamp.timestamp_millis());
        let value = serde_json::to_vec(story)?;

        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;

        Ok(())
    }

    /// Загрузить все активные (не истёкшие) истории
    pub async fn get_active_stories(&self) -> Result<Vec<StoryItem>, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("stories")?;
        let mut stories = Vec::new();

        for entry in tree.iter() {
            if let Ok((_, value)) = entry {
                if let Ok(story) = serde_json::from_slice::<StoryItem>(&value) {
                    if !story.is_expired() {
                        stories.push(story);
                    }
                }
            }
        }

        // Сортировка по времени (новые первыми)
        stories.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

        Ok(stories)
    }

    /// Загрузить истории конкретного автора
    pub async fn get_stories_by_author(&self, author_peer_id: &str) -> Result<Vec<StoryItem>, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("stories")?;
        let mut stories = Vec::new();

        for entry in tree.iter() {
            if let Ok((_, value)) = entry {
                if let Ok(story) = serde_json::from_slice::<StoryItem>(&value) {
                    if story.author_peer_id == author_peer_id && !story.is_expired() {
                        stories.push(story);
                    }
                }
            }
        }

        stories.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

        Ok(stories)
    }

    /// Удалить истёкшие истории из БД
    pub async fn cleanup_expired_stories(&self) -> Result<usize, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("stories")?;
        let mut removed_count = 0;

        let mut keys_to_remove = Vec::new();

        for entry in tree.iter() {
            if let Ok((key, value)) = entry {
                if let Ok(story) = serde_json::from_slice::<StoryItem>(&value) {
                    if story.is_expired() {
                        keys_to_remove.push(key.to_vec());
                    }
                }
            }
        }

        for key in keys_to_remove {
            tree.remove(&key)?;
            removed_count += 1;
        }

        tree.flush()?;

        println!("🧹 Удалено {} истёкших историй", removed_count);

        Ok(removed_count)
    }

    /// Загрузить изображение и создать историю
    pub async fn upload_and_create_story(
        &self,
        file_bytes: Vec<u8>,
        filename: &str,
        caption: Option<String>,
    ) -> Result<StoryItem, Box<dyn Error>> {
        let pinata_client = self.pinata_client.as_ref()
            .ok_or("Pinata клиент не настроен")?;

        // Загружаем в IPFS
        let cid = pinata_client.upload_image(file_bytes, filename).await?;
        println!("📤 Изображение загружено в IPFS: {}", cid);

        // Создаём историю
        let story = StoryItem::new(self.local_peer_id.clone(), cid, caption);

        // Сохраняем локально
        self.save_story(&story).await?;

        Ok(story)
    }

    /// Обработать полученную из Gossipsub историю
    pub async fn process_received_story(&self, broadcast: &StoryBroadcast) -> Result<(), Box<dyn Error>> {
        // Проверяем подпись (в полной версии здесь будет криптографическая верификация)
        // Сейчас просто сохраняем историю

        let db = self.db.read().await;
        let tree = db.open_tree("stories")?;

        // Проверяем, не существует ли уже такая история
        let key = format!("story_{}_{}", broadcast.author_peer_id, broadcast.timestamp.timestamp_millis());
        if tree.get(&key)?.is_some() {
            return Ok(()); // Уже существует
        }

        // Создаём заглушку истории (полный контент будет загружен через IPFS)
        let story = StoryItem {
            cid: broadcast.cid.clone(),
            author_peer_id: broadcast.author_peer_id.clone(),
            timestamp: broadcast.timestamp,
            expires_at: broadcast.timestamp + Duration::hours(24),
            caption: None,
            content_type: "image".to_string(),
        };

        // Сохраняем
        let value = serde_json::to_vec(&story)?;
        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;

        println!("📥 Получена история от {} (CID: {})", broadcast.author_peer_id, broadcast.cid);

        Ok(())
    }

    /// Создать сообщение для Gossipsub broadcast
    pub fn create_broadcast_message(&self, story: &StoryItem) -> StoryBroadcast {
        // Создаём простую подпись (в продакшене использовать Ed25519)
        let signature = format!("sig_{}_{}", story.cid, story.timestamp.timestamp());

        StoryBroadcast::new(
            story.cid.clone(),
            story.author_peer_id.clone(),
            signature,
        )
    }
}

/// Фоновая задача для авто-очистки истёкших историй
pub async fn stories_cleanup_task(manager: Arc<StoryManager>, interval_secs: u64) {
    use tokio::time::Duration;

    let mut interval = tokio::time::interval(Duration::from_secs(interval_secs));

    loop {
        interval.tick().await;

        match manager.cleanup_expired_stories().await {
            Ok(count) => {
                if count > 0 {
                    println!("🧹 Stories cleanup: удалено {} историй", count);
                }
            }
            Err(e) => {
                eprintln!("❌ Ошибка очистки историй: {}", e);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use tokio::sync::RwLock;

    #[test]
    fn test_story_creation() {
        let story = StoryItem::new(
            "test_peer".to_string(),
            "QmTest123".to_string(),
            Some("Test caption".to_string()),
        );

        assert_eq!(story.cid, "QmTest123");
        assert_eq!(story.author_peer_id, "test_peer");
        assert_eq!(story.caption, Some("Test caption".to_string()));
        assert_eq!(story.content_type, "image");
    }

    #[test]
    fn test_story_expiration() {
        let story = StoryItem::new(
            "test_peer".to_string(),
            "QmTest123".to_string(),
            None,
        );

        // История не должна быть истёкшей сразу после создания
        assert!(!story.is_expired());
        assert!(story.time_remaining() > 0);
    }

    #[tokio::test]
    async fn test_story_manager_save_and_load() {
        let db = Arc::new(RwLock::new(sled::open("/tmp/test_stories_db").unwrap()));
        let manager = StoryManager::new(db.clone(), "test_peer".to_string());

        let story = StoryItem::new(
            "test_peer".to_string(),
            "QmTest123".to_string(),
            Some("Test".to_string()),
        );

        manager.save_story(&story).await.unwrap();

        let stories = manager.get_active_stories().await.unwrap();
        assert!(!stories.is_empty());
        assert_eq!(stories[0].cid, "QmTest123");

        // Очистка тестовой БД
        db.write().await.clear().unwrap();
    }
}
