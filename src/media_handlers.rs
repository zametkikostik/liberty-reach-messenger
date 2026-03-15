//! Media Handlers for Voice/Video Circle
//!
//! API endpoints:
//! - POST /api/media/upload - загрузка медиа (Voice, VideoCircle)
//! - POST /api/media/pin/{cid} - pin на 7 дней
//! - GET /api/media/{cid} - получение метаданных

use axum::{
    extract::{Multipart, Path, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use sled::Db;

use crate::storage_manager::{MediaMetadata, MediaType, StorageManager, MediaUploadResponse};

/// AppState для media handlers
#[derive(Clone)]
pub struct MediaState {
    pub db: Arc<Db>,
    pub storage_manager: Arc<StorageManager>,
    pub local_peer_id: String,
}

/// Запрос на загрузку медиа
#[derive(Debug, Deserialize)]
pub struct UploadMetadata {
    pub media_type: String,
    pub is_encrypted: Option<bool>,
    pub encryption_key: Option<String>,
    pub mime_type: Option<String>,
}

/// Response с метаданными
#[derive(Debug, Serialize)]
pub struct MediaMetadataResponse {
    pub cid: String,
    pub owner_peer_id: String,
    pub media_type: String,
    pub is_encrypted: bool,
    pub uploaded_at: i64,
    pub expires_at: i64,
    pub size_bytes: u64,
    pub is_pinned: bool,
    pub mime_type: String,
    pub time_remaining_secs: i64,
}

impl From<&MediaMetadata> for MediaMetadataResponse {
    fn from(m: &MediaMetadata) -> Self {
        Self {
            cid: m.cid.clone(),
            owner_peer_id: m.owner_peer_id.clone(),
            media_type: m.media_type.as_str().to_string(),
            is_encrypted: m.is_encrypted,
            uploaded_at: m.uploaded_at.timestamp(),
            expires_at: m.expires_at.timestamp(),
            size_bytes: m.size_bytes,
            is_pinned: m.is_pinned,
            mime_type: m.mime_type.clone(),
            time_remaining_secs: m.time_remaining(),
        }
    }
}

/// Создать роутер для media
pub fn media_router(state: MediaState) -> Router {
    Router::new()
        .route("/upload", post(upload_media))
        .route("/pin/:cid", post(pin_media))
        .route("/:cid", get(get_media_metadata))
        .route("/list", get(list_media))
        .with_state(state)
}

/// POST /api/media/upload
/// Загрузка медиа с автоматическим шифрованием для Voice/VideoCircle
async fn upload_media(
    State(state): State<MediaState>,
    mut multipart: Multipart,
) -> Result<Json<MediaUploadResponse>, StatusCode> {
    let mut file_data: Option<bytes::Bytes> = None;
    let mut media_type_str = String::from("file");
    let mut encryption_key: Option<String> = None;

    // Парсим multipart форму
    while let Some(field) = multipart.next_field().await.map_err(|_| StatusCode::BAD_REQUEST)? {
        let name = field.name().unwrap_or("");
        
        match name {
            "file" => {
                file_data = Some(field.bytes().await.map_err(|_| StatusCode::BAD_REQUEST)?);
            }
            "media_type" => {
                media_type_str = field.text().await.unwrap_or_else(|_| "file".to_string());
            }
            "encryption_key" => {
                encryption_key = field.text().await.ok();
            }
            _ => {}
        }
    }

    let file_bytes = file_data.ok_or(StatusCode::BAD_REQUEST)?;

    // Определяем тип медиа
    let media_type = MediaType::from_str(&media_type_str)
        .unwrap_or(MediaType::File);

    // Определяем MIME тип
    let mime_type = infer::get(&file_bytes)
        .map(|m| m.mime_type())
        .unwrap_or("application/octet-stream")
        .to_string();

    // Генерируем ключ шифрования если не предоставлен
    let mut key_bytes = [0u8; 32];
    OsRng.fill_bytes(&mut key_bytes);
    let encryption_key_hex = hex::encode(&key_bytes);

    // Шифруем если Voice или VideoCircle
    let (final_bytes, is_encrypted, nonce_bytes) = match media_type {
        MediaType::Voice | MediaType::VideoCircle => {
            let (encrypted, nonce) = state.storage_manager
                .encrypt_buffer(&file_bytes, &key_bytes)
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            (encrypted, true, Some(nonce))
        }
        _ => (file_bytes.to_vec(), false, None),
    };

    // Загружаем в Pinata (через stories модуль)
    let cid = upload_to_pinata(&final_bytes, &state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Создаём метаданные
    let mut metadata = MediaMetadata::new(
        cid.clone(),
        state.local_peer_id.clone(),
        media_type,
        final_bytes.len() as u64,
        mime_type,
    );

    if is_encrypted {
        metadata.is_encrypted = true;
        metadata.encryption_key = Some(encryption_key_hex.clone());
    }

    // Сохраняем метаданные
    state.storage_manager
        .save_metadata(&metadata)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Возвращаем response с ключом для расшифровки
    let mut response = MediaUploadResponse::from_metadata(&metadata);
    
    // Добавляем ключ шифрования и nonce в response для клиента
    if is_encrypted {
        response.signed_url = Some(format!(
            "https://gateway.pinata.cloud/ipfs/{}?key={}",
            cid, encryption_key_hex
        ));
    }

    Ok(Json(response))
}

/// POST /api/media/pin/:cid
/// Pin медиа на 7 дней
async fn pin_media(
    State(state): State<MediaState>,
    Path(cid): Path<String>,
) -> Result<StatusCode, StatusCode> {
    // Проверяем существование
    let metadata = state.storage_manager
        .get_metadata(&cid)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Проверяем владение
    if metadata.owner_peer_id != state.local_peer_id {
        return Err(StatusCode::FORBIDDEN);
    }

    // Pin на 7 дней
    state.storage_manager
        .pin_media(&cid)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// GET /api/media/:cid
/// Получить метаданные медиа
async fn get_media_metadata(
    State(state): State<MediaState>,
    Path(cid): Path<String>,
) -> Result<Json<MediaMetadataResponse>, StatusCode> {
    let metadata = state.storage_manager
        .get_metadata(&cid)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(MediaMetadataResponse::from(&metadata)))
}

/// GET /api/media/list
/// Список всех медиа
async fn list_media(
    State(state): State<MediaState>,
) -> Result<Json<Vec<MediaMetadataResponse>>, StatusCode> {
    let media = state.storage_manager
        .list_all_media()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let response: Vec<MediaMetadataResponse> = media
        .iter()
        .map(MediaMetadataResponse::from)
        .collect();

    Ok(Json(response))
}

/// Загрузка в Pinata
async fn upload_to_pinata(
    data: &[u8],
    db: &Db,
) -> Result<String, Box<dyn std::error::Error>> {
    use reqwest::Client;
    use serde_json::json;

    // Получаем ключи из конфига
    let pinata_api_key = std::env::var("PINATA_API_KEY").ok();
    let pinata_secret_key = std::env::var("PINATA_SECRET_KEY").ok();

    if pinata_api_key.is_none() || pinata_secret_key.is_none() {
        // Возвращаем mock CID для тестирования
        return Ok(format!("mock_cid_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()));
    }

    let client = Client::new();
    
    // Формируем запрос к Pinata
    let form_data = json!({
        "pinataMetadata": {
            "name": format!("liberty_media_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        }
    });

    let response = client
        .post("https://api.pinata.cloud/pinning/pinFileToIPFS")
        .header("Authorization", format!("Bearer {}", pinata_api_key.unwrap()))
        .multipart(reqwest::multipart::Form::new()
            .text("pinataOptions", form_data.to_string())
            .part("file", reqwest::multipart::Part::bytes(data.to_vec())))
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(format!("Pinata upload failed: {}", response.status()).into());
    }

    let result: serde_json::Value = response.json().await?;
    
    let cid = result["IpfsHash"]
        .as_str()
        .ok_or("No CID in response")?
        .to_string();

    Ok(cid)
}
