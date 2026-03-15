//! File Attachments Module for Liberty Reach
//!
//! Функции:
//! - Загрузка файлов в чаты через Pinata IPFS
//! - Поддержка всех типов чатов (1-на-1, группы, каналы)
//! - Шифрование файлов перед загрузкой
//! - Предпросмотр изображений/видео

use chrono::{DateTime, Utc};
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::chat_types::aes_e2ee;
use crate::stories::PinataConfig;

/// Типы прикрепляемых файлов
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum FileType {
    Image,      // Изображения (jpg, png, gif, webp)
    Video,      // Видео (mp4, webm, mov)
    Audio,      // Аудио (mp3, wav, ogg)
    Document,   // Документы (pdf, doc, docx, txt)
    Archive,    // Архивы (zip, rar, 7z)
    Other,      // Другие файлы
}

impl FileType {
    pub fn from_mime_type(mime: &str) -> Self {
        if mime.starts_with("image/") {
            FileType::Image
        } else if mime.starts_with("video/") {
            FileType::Video
        } else if mime.starts_with("audio/") {
            FileType::Audio
        } else if mime.contains("pdf") || mime.contains("document") {
            FileType::Document
        } else if mime.contains("zip") || mime.contains("compressed") {
            FileType::Archive
        } else {
            FileType::Other
        }
    }

    pub fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_lowercase().as_str() {
            "jpg" | "jpeg" | "png" | "gif" | "webp" | "bmp" => Some(FileType::Image),
            "mp4" | "webm" | "mov" | "avi" => Some(FileType::Video),
            "mp3" | "wav" | "ogg" | "flac" => Some(FileType::Audio),
            "pdf" | "doc" | "docx" | "txt" | "rtf" => Some(FileType::Document),
            "zip" | "rar" | "7z" | "tar" | "gz" => Some(FileType::Archive),
            _ => Some(FileType::Other),
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            FileType::Image => "🖼️",
            FileType::Video => "🎬",
            FileType::Audio => "🎵",
            FileType::Document => "📄",
            FileType::Archive => "📦",
            FileType::Other => "📎",
        }
    }
}

/// Прикреплённый файл
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttachedFile {
    /// ID файла
    pub file_id: String,
    /// CID в IPFS
    pub cid: String,
    /// Тип файла
    pub file_type: FileType,
    /// Имя файла
    pub filename: String,
    /// MIME тип
    pub mime_type: String,
    /// Размер в байтах
    pub size_bytes: u64,
    /// Зашифрован ли
    pub is_encrypted: bool,
    /// CID превью (для изображений/видео)
    pub preview_cid: Option<String>,
    /// Время загрузки
    pub uploaded_at: DateTime<Utc>,
    /// PeerID загрузившего
    pub uploader_peer_id: String,
    /// ID чата
    pub chat_id: String,
    /// Срок действия (None = бессрочно)
    pub expires_at: Option<DateTime<Utc>>,
}

impl AttachedFile {
    pub fn new(
        file_id: String,
        cid: String,
        file_type: FileType,
        filename: String,
        mime_type: String,
        size_bytes: u64,
        uploader_peer_id: String,
        chat_id: String,
    ) -> Self {
        Self {
            file_id,
            cid,
            file_type,
            filename,
            mime_type,
            size_bytes,
            is_encrypted: false,
            preview_cid: None,
            uploaded_at: Utc::now(),
            uploader_peer_id,
            chat_id,
            expires_at: None,
        }
    }

    pub fn with_preview(mut self, preview_cid: String) -> Self {
        self.preview_cid = Some(preview_cid);
        self
    }

    pub fn with_encryption(mut self, is_encrypted: bool) -> Self {
        self.is_encrypted = is_encrypted;
        self
    }

    pub fn with_expiry(mut self, expires_at: DateTime<Utc>) -> Self {
        self.expires_at = Some(expires_at);
        self
    }

    /// Получить URL для скачивания
    pub fn get_download_url(&self) -> String {
        format!("https://gateway.pinata.cloud/ipfs/{}", self.cid)
    }

    /// Получить URL для превью
    pub fn get_preview_url(&self) -> Option<String> {
        self.preview_cid
            .as_ref()
            .map(|cid| format!("https://gateway.pinata.cloud/ipfs/{}", cid))
    }
}

/// Менеджер файлов
pub struct FileManager {
    pinata_config: Option<PinataConfig>,
    /// Кэш файлов
    files: Arc<tokio::sync::RwLock<std::collections::HashMap<String, AttachedFile>>>,
}

impl FileManager {
    pub fn new(pinata_config: Option<PinataConfig>) -> Self {
        Self {
            pinata_config,
            files: Arc::new(tokio::sync::RwLock::new(std::collections::HashMap::new())),
        }
    }

    /// Загрузить файл в Pinata
    pub async fn upload_file(
        &self,
        file_bytes: Vec<u8>,
        filename: &str,
        mime_type: &str,
        uploader_peer_id: &str,
        chat_id: &str,
        encrypt: bool,
    ) -> Result<AttachedFile, Box<dyn std::error::Error>> {
        let file_type = FileType::from_mime_type(mime_type);
        let file_id = format!("file_{}_{}", chat_id, uuid::Uuid::new_v4().as_simple());

        // Шифрование если нужно
        let (final_bytes, is_encrypted, encryption_key) = if encrypt {
            let mut key = [0u8; 32];
            OsRng.fill_bytes(&mut key);
            let (encrypted, _nonce) = aes_e2ee::encrypt(&file_bytes, &key)
                .map_err(|e| format!("Encryption error: {}", e))?;
            (encrypted, true, Some(hex::encode(&key)))
        } else {
            (file_bytes, false, None)
        };

        // Загрузка в Pinata
        let cid = self.upload_to_pinata(&final_bytes, &filename).await?;

        // Создание превью для изображений
        let mut attached_file = AttachedFile::new(
            file_id.clone(),
            cid,
            file_type,
            filename.to_string(),
            mime_type.to_string(),
            final_bytes.len() as u64,
            uploader_peer_id.to_string(),
            chat_id.to_string(),
        )
        .with_encryption(is_encrypted);

        // TODO: Генерация превью для изображений/видео
        // if file_type == FileType::Image || file_type == FileType::Video {
        //     let preview_bytes = self.generate_preview(&final_bytes).await?;
        //     let preview_cid = self.upload_to_pinata(&preview_bytes, &format!("preview_{}", filename)).await?;
        //     attached_file = attached_file.with_preview(preview_cid);
        // }

        // Сохранение в кэш
        let mut files = self.files.write().await;
        files.insert(file_id.clone(), attached_file.clone());

        Ok(attached_file)
    }

    /// Загрузка в Pinata
    async fn upload_to_pinata(&self, file_bytes: &[u8], filename: &str) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(ref config) = self.pinata_config {
            // Используем stories::PinataClient
            use crate::stories::PinataClient;
            
            let client = PinataClient::new(config.clone());
            let cid = client.upload_image(file_bytes.to_vec(), filename).await?;
            Ok(cid)
        } else {
            // Mock CID для тестирования
            Ok(format!("mock_cid_{}", uuid::Uuid::new_v4().as_simple()))
        }
    }

    /// Получить файл по ID
    pub async fn get_file(&self, file_id: &str) -> Option<AttachedFile> {
        let files = self.files.read().await;
        files.get(file_id).cloned()
    }

    /// Получить файлы чата
    pub async fn get_chat_files(&self, chat_id: &str) -> Vec<AttachedFile> {
        let files = self.files.read().await;
        files
            .values()
            .filter(|f| f.chat_id == chat_id)
            .cloned()
            .collect()
    }

    /// Удалить файл
    pub async fn delete_file(&self, file_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut files = self.files.write().await;
        files.remove(file_id);
        // TODO: Unpin из Pinata
        Ok(())
    }

    /// Установить Pinata конфиг
    pub fn set_pinata_config(&mut self, config: PinataConfig) {
        self.pinata_config = Some(config);
    }
}

/// Эмодзи и смайлики
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmojiPack {
    pub pack_id: String,
    pub name: String,
    pub emojis: Vec<Emoji>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Emoji {
    pub emoji_id: String,
    pub unicode: String,
    pub shortcodes: Vec<String>, // :smile:, :happy:, etc.
    pub category: EmojiCategory,
    pub tags: Vec<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum EmojiCategory {
    Smileys,        // 😀
    People,         // 👍
    Animals,        // 🐶
    Food,           // 🍎
    Travel,         // ✈️
    Activities,     // ⚽
    Objects,        // 💡
    Symbols,        // ❤️
    Flags,          // 🇧🇬
    Custom,         // Кастомные стикеры
}

/// Реакция на сообщение
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageReaction {
    pub message_id: String,
    pub emoji: String,
    pub user_peer_id: String,
    pub timestamp: DateTime<Utc>,
}

/// Менеджер эмодзи
pub struct EmojiManager {
    /// Доступные паки эмодзи
    packs: Arc<tokio::sync::RwLock<Vec<EmojiPack>>>,
    /// Недавние эмодзи
    recent: Arc<tokio::sync::RwLock<Vec<Emoji>>>,
}

impl EmojiManager {
    pub fn new() -> Self {
        Self {
            packs: Arc::new(tokio::sync::RwLock::new(Vec::new())),
            recent: Arc::new(tokio::sync::RwLock::new(Vec::new())),
        }
    }

    /// Инициализировать стандартные паки
    pub async fn init_default_packs(&self) {
        let mut packs = self.packs.write().await;
        
        // Базовый пак смайликов
        packs.push(EmojiPack {
            pack_id: "default_smileys".to_string(),
            name: "Смайлики".to_string(),
            emojis: vec![
                Emoji {
                    emoji_id: "smile".to_string(),
                    unicode: "😀".to_string(),
                    shortcodes: vec!["smile".to_string(), "happy".to_string()],
                    category: EmojiCategory::Smileys,
                    tags: vec!["happy".to_string(), "joy".to_string()],
                },
                Emoji {
                    emoji_id: "laugh".to_string(),
                    unicode: "😂".to_string(),
                    shortcodes: vec!["laugh".to_string(), "lol".to_string()],
                    category: EmojiCategory::Smileys,
                    tags: vec!["laugh".to_string(), "tears".to_string()],
                },
                Emoji {
                    emoji_id: "heart".to_string(),
                    unicode: "❤️".to_string(),
                    shortcodes: vec!["heart".to_string(), "love".to_string()],
                    category: EmojiCategory::Symbols,
                    tags: vec!["love".to_string(), "like".to_string()],
                },
                Emoji {
                    emoji_id: "thumbs_up".to_string(),
                    unicode: "👍".to_string(),
                    shortcodes: vec!["thumbsup".to_string(), "like".to_string()],
                    category: EmojiCategory::People,
                    tags: vec!["approve".to_string(), "ok".to_string()],
                },
                Emoji {
                    emoji_id: "bulgaria_flag".to_string(),
                    unicode: "🇧🇬".to_string(),
                    shortcodes: vec!["bulgaria".to_string(), "bg".to_string()],
                    category: EmojiCategory::Flags,
                    tags: vec!["Bulgaria".to_string(), "BG".to_string()],
                },
            ],
        });
    }

    /// Добавить реакцию на сообщение
    pub async fn add_reaction(
        &self,
        message_id: &str,
        emoji: &str,
        user_peer_id: &str,
    ) -> MessageReaction {
        MessageReaction {
            message_id: message_id.to_string(),
            emoji: emoji.to_string(),
            user_peer_id: user_peer_id.to_string(),
            timestamp: Utc::now(),
        }
    }

    /// Получить эмодзи по shortcode
    pub async fn get_emoji_by_shortcode(&self, shortcode: &str) -> Option<Emoji> {
        let packs = self.packs.read().await;
        for pack in packs.iter() {
            for emoji in &pack.emojis {
                if emoji.shortcodes.contains(&shortcode.to_string()) {
                    return Some(emoji.clone());
                }
            }
        }
        None
    }

    /// Получить все эмодзи категории
    pub async fn get_emojis_by_category(&self, category: EmojiCategory) -> Vec<Emoji> {
        let packs = self.packs.read().await;
        packs
            .iter()
            .flat_map(|pack| pack.emojis.iter().filter(|e| e.category == category).cloned())
            .collect()
    }

    /// Поиск эмодзи по тегам
    pub async fn search_emojis(&self, query: &str) -> Vec<Emoji> {
        let packs = self.packs.read().await;
        let query_lower = query.to_lowercase();
        
        packs
            .iter()
            .flat_map(|pack| {
                pack.emojis.iter().filter(|e| {
                    e.tags.iter().any(|t| t.to_lowercase().contains(&query_lower))
                        || e.shortcodes.iter().any(|s| s.to_lowercase().contains(&query_lower))
                }).cloned()
            })
            .collect()
    }

    /// Добавить в недавние
    pub async fn add_to_recent(&self, emoji: Emoji) {
        let mut recent = self.recent.write().await;
        recent.insert(0, emoji);
        if recent.len() > 50 {
            recent.truncate(50);
        }
    }

    /// Получить недавние эмодзи
    pub async fn get_recent(&self) -> Vec<Emoji> {
        let recent = self.recent.read().await;
        recent.clone()
    }
}

impl Default for EmojiManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_file_type_from_mime() {
        assert_eq!(FileType::from_mime_type("image/jpeg"), FileType::Image);
        assert_eq!(FileType::from_mime_type("video/mp4"), FileType::Video);
        assert_eq!(FileType::from_mime_type("audio/mp3"), FileType::Audio);
        assert_eq!(FileType::from_mime_type("application/pdf"), FileType::Document);
    }

    #[test]
    fn test_file_type_icon() {
        assert_eq!(FileType::Image.icon(), "🖼️");
        assert_eq!(FileType::Video.icon(), "🎬");
        assert_eq!(FileType::Audio.icon(), "🎵");
    }

    #[tokio::test]
    async fn test_emoji_manager() {
        let manager = EmojiManager::new();
        manager.init_default_packs().await;

        let emoji = manager.get_emoji_by_shortcode("smile").await;
        assert!(emoji.is_some());
        assert_eq!(emoji.unwrap().unicode, "😀");

        let bulgarian = manager.get_emoji_by_shortcode("bulgaria").await;
        assert!(bulgarian.is_some());
        assert_eq!(bulgarian.unwrap().unicode, "🇧🇬");
    }
}
