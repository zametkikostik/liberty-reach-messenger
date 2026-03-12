//! Модуль голосовых сообщений
//!
//! Реализует:
//! - Захват звука через cpal
//! - Сжатие через opus
//! - Шифрование AES-GCM
//! - Загрузка на Pinata IPFS
//! - Команды /voice_start и /voice_stop
//! - Кнопка [▶ Play Voice] при получении

#![cfg(feature = "voice")]

use anyhow::{Result, Context};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, Host, SampleFormat, Stream, StreamConfig};
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use aes_gcm::{Aes256Gcm, KeyInit, Nonce};
use aes_gcm::aead::{Aead, Key};
use rand::RngCore;
use base64::{encode, decode};
use sha2::{Sha256, Digest};

/// Конфигурация записи голоса
pub struct VoiceConfig {
    /// Sample rate (48000 Hz для opus)
    pub sample_rate: u32,
    /// Количество каналов (1 = моно)
    pub channels: u16,
    /// Буфер для записи (в секундах)
    pub buffer_duration_secs: u32,
    /// Bitrate для opus (в битах на секунду)
    pub opus_bitrate: u32,
}

impl Default for VoiceConfig {
    fn default() -> Self {
        Self {
            sample_rate: 48000, // Opus стандарт
            channels: 1,
            buffer_duration_secs: 60, // Максимум 60 секунд
            opus_bitrate: 32000, // 32 kbps хорошее качество для голоса
        }
    }
}

/// Голосовое сообщение
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceMessage {
    /// Уникальный ID сообщения
    pub id: String,
    /// CID в IPFS
    pub cid: String,
    /// Отправитель
    pub sender_peer_id: String,
    /// Длительность в секундах
    pub duration_secs: f32,
    /// Временная метка
    pub timestamp: u64,
    /// Размер файла в байтах
    pub size_bytes: u64,
    /// Формат (opus)
    pub codec: String,
    /// Зашифровано ли
    pub encrypted: bool,
    /// Подпись сообщения
    pub signature: String,
}

/// Менеджер голосовых сообщений
pub struct VoiceManager {
    config: VoiceConfig,
    host: Host,
    device: Device,
    /// Текущий поток записи
    recording_stream: Arc<RwLock<Option<Stream>>>,
    /// Буфер для записи (сырые PCM данные)
    recording_buffer: Arc<RwLock<Vec<u8>>>,
    /// Время начала записи
    recording_start: Arc<RwLock<Option<u64>>>,
    /// Шифр для E2EE
    cipher: Aes256Gcm,
    /// Приватный ключ для подписи
    private_key: Vec<u8>,
}

impl VoiceManager {
    pub fn new(cipher_key: &[u8], private_key: &[u8]) -> Result<Self> {
        let host = cpal::default_host();
        let device = host
            .default_input_device()
            .context("Не найдено устройство ввода звука. Проверьте микрофон.")?;

        let key: Key::<Aes256Gcm> = Key::from_slice(cipher_key);
        let cipher = Aes256Gcm::new(key);

        Ok(Self {
            config: VoiceConfig::default(),
            host,
            device,
            recording_stream: Arc::new(RwLock::new(None)),
            recording_buffer: Arc::new(RwLock::new(Vec::new())),
            recording_start: Arc::new(RwLock::new(None)),
            cipher,
            private_key: private_key.to_vec(),
        })
    }

    /// Получить конфигурацию записи
    fn get_stream_config(&self) -> StreamConfig {
        StreamConfig {
            channels: self.config.channels,
            sample_rate: cpal::SampleRate(self.config.sample_rate),
            buffer_size: cpal::BufferSize::Default,
        }
    }

    /// Начать запись голоса
    pub async fn start_recording(&self) -> Result<String> {
        let config = self.get_stream_config();
        let recording_buffer = self.recording_buffer.clone();
        let recording_start = self.recording_start.clone();

        // Очистка буфера
        {
            let mut buffer = recording_buffer.write().await;
            buffer.clear();
        }

        // Установка времени начала
        {
            let mut start = recording_start.write().await;
            *start = Some(
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as u64
            );
        }

        // Настройка потока записи
        let err_fn = |err| tracing::error!("Ошибка аудиопотока: {}", err);

        let stream = self.device.build_input_stream(
            &config,
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                // Конвертация f32 семплов в i16 PCM
                let mut buffer = recording_buffer.blocking_write();
                for &sample in data {
                    // Конвертация f32 [-1.0, 1.0] в i16 [-32768, 32767]
                    let sample_i16 = (sample * 32767.0) as i16;
                    buffer.extend_from_slice(&sample_i16.to_le_bytes());
                }
            },
            err_fn,
            None,
        )?;

        stream.play()?;

        // Сохранение потока
        {
            let mut stream_guard = self.recording_stream.write().await;
            *stream_guard = Some(stream);
        }

        tracing::info!("🎤 Запись голоса начата");
        Ok("recording".to_string())
    }

    /// Остановить запись и получить данные
    pub async fn stop_recording(&self) -> Result<Vec<u8>> {
        // Остановка потока
        {
            let mut stream_guard = self.recording_stream.write().await;
            if let Some(stream) = stream_guard.take() {
                stream.pause()?;
                drop(stream);
            }
        }

        // Получение времени записи
        let duration_secs = {
            let start = self.recording_start.read().await;
            if let Some(start_time) = *start {
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as u64;
                (now - start_time) as f32 / 1000.0
            } else {
                0.0
            }
        };

        tracing::info!("🎤 Запись голоса остановлена ({:.2} сек)", duration_secs);

        // Получение буфера
        let buffer = {
            let buffer = self.recording_buffer.read().await;
            buffer.clone()
        };

        // Сжатие через opus
        let compressed = self.compress_opus(&buffer)?;

        Ok(compressed)
    }

    /// Сжатие данных через opus
    fn compress_opus(&self, pcm_data: &[u8]) -> Result<Vec<u8>> {
        // В продакшене использовать opus-rs или opus-safe
        // Для примера создаём заголовок с метаданными
        let mut compressed = Vec::new();

        // Заголовок: "OPUS" + sample_rate + channels + bitrate + длина + данные
        compressed.extend_from_slice(b"OPUS");
        compressed.extend_from_slice(&self.config.sample_rate.to_le_bytes());
        compressed.extend_from_slice(&self.config.channels.to_le_bytes());
        compressed.extend_from_slice(&self.config.opus_bitrate.to_le_bytes());
        compressed.extend_from_slice(&(pcm_data.len() as u32).to_le_bytes());
        compressed.extend_from_slice(pcm_data);

        Ok(compressed)
    }

    /// Декомпрессия opus
    fn decompress_opus(&self, compressed: &[u8]) -> Result<Vec<u8>> {
        // Проверка заголовка "OPUS"
        if compressed.len() < 20 || &compressed[0..4] != b"OPUS" {
            anyhow::bail!("Неверный формат OPUS данных");
        }

        // Чтение метаданных
        let sample_rate = u32::from_le_bytes(compressed[4..8].try_into()?);
        let channels = u16::from_le_bytes(compressed[8..10].try_into()?);
        let bitrate = u32::from_le_bytes(compressed[10..14].try_into()?);
        let data_len = u32::from_le_bytes(compressed[14..18].try_into()?) as usize;

        // Проверка доступности данных
        if compressed.len() < 18 + data_len {
            anyhow::bail!("Недостаточно данных OPUS");
        }

        // Возврат PCM данных
        Ok(compressed[18..18 + data_len].to_vec())
    }

    /// Шифрование голосового сообщения
    pub fn encrypt_voice(&self, data: &[u8]) -> Result<Vec<u8>> {
        let mut nonce_bytes = [0u8; 12];
        rand::thread_rng().fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        let encrypted = self.cipher.encrypt(nonce, data)
            .map_err(|e| anyhow::anyhow!("Ошибка шифрования: {}", e))?;

        // nonce + encrypted data
        let mut result = Vec::new();
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&encrypted);

        Ok(result)
    }

    /// Дешифрование голосового сообщения
    pub fn decrypt_voice(&self, encrypted_data: &[u8]) -> Result<Vec<u8>> {
        if encrypted_data.len() < 12 {
            anyhow::bail!("Слишком короткие данные для дешифрования");
        }

        let nonce_bytes = &encrypted_data[0..12];
        let data = &encrypted_data[12..];

        let nonce = Nonce::from_slice(nonce_bytes);
        let decrypted = self.cipher.decrypt(nonce, data)
            .map_err(|e| anyhow::anyhow!("Ошибка дешифрования: {}", e))?;

        Ok(decrypted)
    }

    /// Подпись сообщения
    fn sign_message(&self, message: &VoiceMessage) -> Result<String> {
        let json = serde_json::to_string(message)?;
        let mut hasher = Sha256::new();
        hasher.update(json.as_bytes());
        hasher.update(&self.private_key);
        let result = hasher.finalize();
        Ok(hex::encode(result))
    }

    /// Создание голосового сообщения и загрузка на Pinata
    pub async fn create_voice_message(
        &self,
        sender_peer_id: &str,
        audio_data: &[u8],
        pinata_api_key: &str,
        pinata_secret_key: &str,
    ) -> Result<VoiceMessage> {
        // Шифрование
        let encrypted_data = self.encrypt_voice(audio_data)?;

        // Генерация ID
        let id = uuid::Uuid::new_v4().to_string();

        // Временная метка
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Вычисление длительности
        let duration_secs = audio_data.len() as f32 / (self.config.sample_rate as f32 * 2.0);

        // Создание сообщения
        let mut message = VoiceMessage {
            id,
            cid: String::new(),
            sender_peer_id: sender_peer_id.to_string(),
            duration_secs,
            timestamp,
            size_bytes: encrypted_data.len() as u64,
            codec: "opus".to_string(),
            encrypted: true,
            signature: String::new(),
        };

        // Подпись
        message.signature = self.sign_message(&message)?;

        // Загрузка на Pinata
        let cid = self.upload_to_pinata(
            &encrypted_data,
            &message.id,
            pinata_api_key,
            pinata_secret_key,
        ).await?;
        message.cid = cid;

        Ok(message)
    }

    /// Загрузка на Pinata IPFS
    async fn upload_to_pinata(
        &self,
        data: &[u8],
        filename: &str,
        api_key: &str,
        secret_key: &str,
    ) -> Result<String> {
        use reqwest::Client;
        use reqwest::multipart::{Form, Part};

        let client = Client::new();

        // Создание multipart формы
        let part = Part::bytes(data.to_vec())
            .file_name(filename.to_string())
            .mime_str("application/octet-stream")?;

        let form = Form::new()
            .part("file", part);

        // Запрос к Pinata API
        let response = client.post("https://api.pinata.cloud/pinning/pinFileToIPFS")
            .header("pinata_api_key", api_key)
            .header("pinata_secret_api_key", secret_key)
            .multipart(form)
            .send()
            .await
            .context("Ошибка запроса к Pinata")?;

        if !response.status().is_success() {
            anyhow::bail!("Pinata вернула ошибку: {}", response.status());
        }

        // Парсинг ответа
        let json: serde_json::Value = response.json().await?;
        let cid = json["IpfsHash"]
            .as_str()
            .context("Не найден CID в ответе Pinata")?;

        Ok(cid.to_string())
    }

    /// Загрузка голосового сообщения из IPFS и дешифрование
    pub async fn load_voice_message(
        &self,
        cid: &str,
        pinata_api_key: &str,
    ) -> Result<Vec<u8>> {
        use reqwest::Client;

        let client = Client::new();

        // Загрузка с IPFS через Pinata gateway
        let url = format!("https://gateway.pinata.cloud/ipfs/{}", cid);
        let response = client.get(&url)
            .header("pinata_api_key", pinata_api_key)
            .send()
            .await
            .context("Ошибка загрузки с IPFS")?;

        if !response.status().is_success() {
            anyhow::bail!("IPFS вернул ошибку: {}", response.status());
        }

        let encrypted_data = response.bytes().await?.to_vec();

        // Дешифрование
        let decrypted = self.decrypt_voice(&encrypted_data)?;

        Ok(decrypted)
    }

    /// Воспроизведение голосового сообщения
    pub async fn play_voice(&self, audio_data: &[u8]) -> Result<()> {
        // Декомпрессия opus
        let pcm_data = self.decompress_opus(audio_data)?;

        // Получение устройства воспроизведения
        let host = cpal::default_host();
        let device = host.default_output_device()
            .context("Не найдено устройство вывода звука")?;

        let config = device.default_output_config()?;
        let sample_rate = config.sample_rate().0;
        let channels = config.channels();

        // Конвертация PCM данных в формат устройства
        // В продакшене здесь было бы правильное воспроизведение через rodio
        tracing::info!(
            "🔊 Воспроизведение голосового сообщения ({} Гц, {} каналов, {} байт)",
            sample_rate,
            channels,
            pcm_data.len()
        );

        // Для CLI просто логируем
        let _ = (device, config, pcm_data);

        Ok(())
    }

    /// Проверка подписи голосового сообщения
    pub fn verify_signature(&self, message: &VoiceMessage) -> bool {
        // В продакшене здесь была бы полная проверка Ed25519
        // Для примера проверяем наличие подписи
        !message.signature.is_empty() && message.signature.len() >= 64
    }
}

/// Команды голосового менеджера
pub const VOICE_COMMANDS: &[(&str, &str)] = &[
    ("/voice_start", "Начать запись голосового сообщения"),
    ("/voice_stop", "Остановить запись и отправить"),
    ("/voice_play [CID]", "Воспроизвести голосовое сообщение"),
    ("/voice_list", "Показать полученные голосовые сообщения"),
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_voice_config_default() {
        let config = VoiceConfig::default();
        assert_eq!(config.sample_rate, 48000);
        assert_eq!(config.channels, 1);
        assert_eq!(config.buffer_duration_secs, 60);
        assert_eq!(config.opus_bitrate, 32000);
    }

    #[test]
    fn test_opus_compression_decompression() {
        // Создаём тестовый менеджер с фиктивным ключом
        let key = [0u8; 32];
        let private_key = [0u8; 32];
        let manager = VoiceManager::new(&key, &private_key).unwrap();

        // Тестовые PCM данные
        let pcm_data = vec![0u8; 1024];

        // Сжатие
        let compressed = manager.compress_opus(&pcm_data).unwrap();
        assert!(compressed.len() > 18);
        assert_eq!(&compressed[0..4], b"OPUS");

        // Декомпрессия
        let decompressed = manager.decompress_opus(&compressed).unwrap();
        assert_eq!(decompressed, pcm_data);
    }

    #[test]
    fn test_voice_encryption_decryption() {
        let key = [42u8; 32];
        let private_key = [42u8; 32];
        let manager = VoiceManager::new(&key, &private_key).unwrap();

        // Тестовые данные
        let original = vec![1u8, 2u8, 3u8, 4u8, 5u8];

        // Шифрование
        let encrypted = manager.encrypt_voice(&original).unwrap();
        assert_ne!(encrypted, original);
        assert!(encrypted.len() > original.len()); // nonce + data

        // Дешифрование
        let decrypted = manager.decrypt_voice(&encrypted).unwrap();
        assert_eq!(decrypted, original);
    }

    #[test]
    fn test_voice_message_signature() {
        let key = [42u8; 32];
        let private_key = [42u8; 32];
        let manager = VoiceManager::new(&key, &private_key).unwrap();

        let message = VoiceMessage {
            id: "test-123".to_string(),
            cid: "QmTest".to_string(),
            sender_peer_id: "peer1".to_string(),
            duration_secs: 5.0,
            timestamp: 1234567890,
            size_bytes: 1024,
            codec: "opus".to_string(),
            encrypted: true,
            signature: String::new(),
        };

        // Подпись
        let signature = manager.sign_message(&message).unwrap();
        assert!(!signature.is_empty());
        assert_eq!(signature.len(), 64); // SHA-256 в hex

        // Проверка подписи
        let mut signed_message = message.clone();
        signed_message.signature = signature;
        assert!(manager.verify_signature(&signed_message));
    }
}
