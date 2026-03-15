//! Storage Manager for Voice/Video Circle with IPFS
//!
//! Features:
//! - MediaType enum: Voice, VideoCircle
//! - Pre-upload encryption
//! - 7-day retention policy
//! - Background garbage collector
//! - Pinning management via Pinata

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sled::Db;
use std::sync::Arc;
use std::time::Duration as StdDuration;

use crate::chat_types::aes_e2ee;

/// Типы медиа для Voice/Video Circle
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum MediaType {
    /// Голосовое сообщение
    Voice,
    /// Видео в круге (Video Circle)
    VideoCircle,
    /// Изображение
    Image,
    /// Файл
    File,
}

impl MediaType {
    pub fn as_str(&self) -> &'static str {
        match self {
            MediaType::Voice => "voice",
            MediaType::VideoCircle => "video_circle",
            MediaType::Image => "image",
            MediaType::File => "file",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "voice" => Some(MediaType::Voice),
            "video_circle" => Some(MediaType::VideoCircle),
            "image" => Some(MediaType::Image),
            "file" => Some(MediaType::File),
            _ => None,
        }
    }
}

/// Метаданные медиафайла
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaMetadata {
    /// IPFS CID
    pub cid: String,
    /// PeerID владельца
    pub owner_peer_id: String,
    /// Тип медиа
    pub media_type: MediaType,
    /// Время загрузки
    pub uploaded_at: DateTime<Utc>,
    /// Время истечения (24h по умолчанию, 7 дней если pinned)
    pub expires_at: DateTime<Utc>,
    /// Зашифровано ли
    pub is_encrypted: bool,
    /// Ключ шифрования (опционально, для E2EE)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub encryption_key: Option<String>,
    /// Размер файла в байтах
    pub size_bytes: u64,
    /// Pinned ли в IPFS
    pub is_pinned: bool,
    /// MIME тип
    pub mime_type: String,
}

impl MediaMetadata {
    pub fn new(
        cid: String,
        owner_peer_id: String,
        media_type: MediaType,
        size_bytes: u64,
        mime_type: String,
    ) -> Self {
        let now = Utc::now();
        // По умолчанию 24 часа
        let expires_at = now + Duration::hours(24);

        Self {
            cid,
            owner_peer_id,
            media_type,
            uploaded_at: now,
            expires_at,
            is_encrypted: false,
            encryption_key: None,
            size_bytes,
            is_pinned: false,
            mime_type,
        }
    }

    /// Установить 7-дневный срок
    pub fn pin_for_7_days(&mut self) {
        self.expires_at = Utc::now() + Duration::days(7);
        self.is_pinned = true;
    }

    /// Проверка истечения
    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }

    /// Оставшееся время в секундах
    pub fn time_remaining(&self) -> i64 {
        (self.expires_at - Utc::now()).num_seconds().max(0)
    }
}

/// Storage Manager для управления медиа
pub struct StorageManager {
    db: Arc<Db>,
    pinata_api_key: Option<String>,
    pinata_secret_key: Option<String>,
}

impl StorageManager {
    pub fn new(
        db: Arc<Db>,
        pinata_api_key: Option<String>,
        pinata_secret_key: Option<String>,
    ) -> Self {
        Self {
            db,
            pinata_api_key,
            pinata_secret_key,
        }
    }

    /// Сохранить метаданные медиа
    pub fn save_metadata(&self, metadata: &MediaMetadata) -> Result<(), Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let key = format!("media_{}", metadata.cid);
        tree.insert(key.as_bytes(), serde_json::to_vec(metadata)?)?;
        tree.flush()?;
        Ok(())
    }

    /// Получить метаданные по CID
    pub fn get_metadata(&self, cid: &str) -> Result<Option<MediaMetadata>, Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let key = format!("media_{}", cid);
        if let Some(bytes) = tree.get(key.as_bytes())? {
            Ok(Some(serde_json::from_slice(&bytes)?))
        } else {
            Ok(None)
        }
    }

    /// Pin медиа на 7 дней
    pub fn pin_media(&self, cid: &str) -> Result<(), Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let key = format!("media_{}", cid);

        if let Some(bytes) = tree.get(key.as_bytes())? {
            let mut metadata: MediaMetadata = serde_json::from_slice(&bytes)?;
            metadata.pin_for_7_days();
            tree.insert(key.as_bytes(), serde_json::to_vec(&metadata)?)?;
            tree.flush()?;
        }

        Ok(())
    }

    /// Получить все просроченные медиа
    pub fn get_expired_media(&self) -> Result<Vec<MediaMetadata>, Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let mut expired = Vec::new();

        for entry in tree.iter() {
            if let Ok((_, value)) = entry {
                if let Ok(metadata) = serde_json::from_slice::<MediaMetadata>(&value) {
                    if metadata.is_expired() {
                        expired.push(metadata);
                    }
                }
            }
        }

        Ok(expired)
    }

    /// Удалить метаданные медиа
    pub fn remove_metadata(&self, cid: &str) -> Result<(), Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let key = format!("media_{}", cid);
        tree.remove(key.as_bytes())?;
        tree.flush()?;
        Ok(())
    }

    /// Зашифровать буфер перед загрузкой
    pub fn encrypt_buffer(&self, buffer: &[u8], key: &[u8; 32]) -> Result<(Vec<u8>, Vec<u8>), Box<dyn std::error::Error + Send + Sync>> {
        aes_e2ee::encrypt(buffer, key)
    }

    /// Расшифровать буфер
    pub fn decrypt_buffer(&self, ciphertext: &[u8], nonce: &[u8], key: &[u8; 32]) -> Result<Vec<u8>, Box<dyn std::error::Error + Send + Sync>> {
        let decrypted = aes_e2ee::decrypt(ciphertext, nonce, key)?;
        Ok(decrypted.to_vec())
    }

    /// Запустить фоновую задачу очистки
    pub async fn start_garbage_collector(self: Arc<Self>, check_interval_hours: u64) {
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(StdDuration::from_secs(check_interval_hours * 3600));

            loop {
                interval.tick().await;

                match self.run_gc_cycle().await {
                    Ok(count) => {
                        println!("🧹 GC: Удалено {} просроченных медиа", count);
                    }
                    Err(e) => {
                        eprintln!("❌ GC ошибка: {}", e);
                    }
                }
            }
        });
    }

    /// Один цикл очистки
    pub async fn run_gc_cycle(&self) -> Result<usize, Box<dyn std::error::Error>> {
        let expired = self.get_expired_media()?;
        let mut removed_count = 0;

        for metadata in &expired {
            // Unpin из Pinata если нужно
            if metadata.is_pinned {
                if let Err(e) = self.unpin_from_pinata(&metadata.cid).await {
                    eprintln!("⚠️ Не удалось unpin {}: {}", metadata.cid, e);
                }
            }

            // Удаляем метаданные
            if let Err(e) = self.remove_metadata(&metadata.cid) {
                eprintln!("⚠️ Не удалось удалить метаданные {}: {}", metadata.cid, e);
            } else {
                removed_count += 1;
            }
        }

        Ok(removed_count)
    }

    /// Unpin из Pinata
    pub async fn unpin_from_pinata(&self, cid: &str) -> Result<(), Box<dyn std::error::Error>> {
        let api_key = self.pinata_api_key.as_ref()
            .ok_or("Pinata API key not configured")?;

        let client = reqwest::Client::new();
        let url = format!("https://api.pinata.cloud/pinning/unpin/{}", cid);

        let response = client
            .delete(&url)
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("Pinata unpin failed: {}", response.status()).into());
        }

        Ok(())
    }

    /// Получить список всех медиа
    pub fn list_all_media(&self) -> Result<Vec<MediaMetadata>, Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("media_metadata")?;
        let mut media = Vec::new();

        for entry in tree.iter() {
            if let Ok((_, value)) = entry {
                if let Ok(metadata) = serde_json::from_slice::<MediaMetadata>(&value) {
                    media.push(metadata);
                }
            }
        }

        Ok(media)
    }
}

/// Response для API
#[derive(Debug, Serialize)]
pub struct MediaUploadResponse {
    pub cid: String,
    pub media_type: String,
    pub is_encrypted: bool,
    pub expires_at: i64,
    pub size_bytes: u64,
    pub signed_url: Option<String>,
}

impl MediaUploadResponse {
    pub fn from_metadata(metadata: &MediaMetadata) -> Self {
        Self {
            cid: metadata.cid.clone(),
            media_type: metadata.media_type.as_str().to_string(),
            is_encrypted: metadata.is_encrypted,
            expires_at: metadata.expires_at.timestamp(),
            size_bytes: metadata.size_bytes,
            signed_url: Some(format!("https://gateway.pinata.cloud/ipfs/{}", metadata.cid)),
        }
    }
}
