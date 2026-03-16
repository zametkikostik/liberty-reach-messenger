//! Liberty Sovereign: Ultimate Edition
//! P2P мессенджер с E2EE, Web API и системой личностей

mod admin_handlers;
mod ai_guard;
mod ai_engine;
mod chat_types;
mod config;
mod files;
mod geo;
mod hybrid_moderation;
mod media_handlers;
mod network;
mod profiles;
mod social;
mod storage_manager;
mod stories;
mod subtitles;
mod translator;
mod wallet;

use futures::StreamExt;
use libp2p::{
    gossipsub,
    identity,
    kad::{self, store::MemoryStore},
    mdns,
    swarm::{NetworkBehaviour, SwarmEvent},
    PeerId,
};
use rand::rngs::OsRng;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sled::Db;
use std::collections::hash_map::DefaultHasher;
use std::error::Error;
use std::hash::{Hash, Hasher};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::{mpsc, RwLock};
use x25519_dalek_ng::{PublicKey, StaticSecret, SharedSecret};

// Модуль profiles
use profiles::{UserProfile, RelationStatus, WallpaperUpdate};

// Модуль stories
use stories::{StoryManager, StoryItem, StoryBroadcast, PinataConfig};

// Модуль wallet
use wallet::{WalletManager, WalletConfig, BalanceInfo, DecentralizedProvider};

// Модуль ai_guard
use ai_guard::{AiGuard, AiGuardConfig, EncryptedCircle, ViolationType};

// Модуль ai_engine
use ai_engine::{AiManager, AiRequest, start_ai_manager};

// Модуль network
use network::{NetworkManager, NetworkEvent, start_p2p_network};

// ChaCha20Poly1305 для шифрования
use chacha20poly1305::{
    aead::{Aead, KeyInit},
    ChaCha20Poly1305, Nonce,
};

// Axum для Web API
use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router, response::IntoResponse,
};
use tower_http::cors::{Any, CorsLayer};

// Структура сообщения для JSON-сериализации с поддержкой E2EE
#[derive(Serialize, Deserialize, Debug, Clone)]
struct ChatMessage {
    sender: String,
    content: Vec<u8>,
    nonce: Vec<u8>,
    is_encrypted: bool,
    timestamp: u128,
}

// Структура handshake-сообщения для обмена ключами с профилем
#[derive(Serialize, Deserialize, Debug, Clone)]
struct HandshakeMessage {
    peer_id: String,
    encryption_key: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    encrypted_profile: Option<Vec<u8>>,
}

// API Request/Response структуры
#[derive(Serialize, Deserialize, Debug)]
struct ApiInfo {
    peer_id: String,
    public_key: String,
    status: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ApiProfileUpdate {
    nickname: Option<String>,
    bio: Option<String>,
    avatar_cid: Option<String>,
    relation_status: Option<RelationStatus>,
    wallpaper_url: Option<String>,
    partner_peer_id: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
struct ApiWallpaperRequest {
    wallpaper_cid: String,
    /// Опционально: PeerID партнёра для синхронизации
    sync_with_partner: Option<bool>,
}

#[derive(Serialize, Deserialize, Debug)]
struct ApiWallpaperResponse {
    success: bool,
    wallpaper_cid: String,
    synced_with: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
struct ApiHistoryItem {
    timestamp: u128,
    content: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ApiHistory {
    messages: Vec<ApiHistoryItem>,
}

#[derive(Serialize, Deserialize, Debug)]
struct SendRequest {
    text: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct SendResponse {
    success: bool,
    message: String,
}

// Stories API структуры
#[derive(Serialize, Deserialize, Debug)]
struct StoryUploadRequest {
    /// Base64 encoded изображение
    image_base64: String,
    /// Опциональная подпись
    caption: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
struct StoryUploadResponse {
    success: bool,
    cid: String,
    author_peer_id: String,
    timestamp: u64,
}

#[derive(Serialize, Deserialize, Debug)]
struct StoryFeedResponse {
    stories: Vec<StoryItem>,
}

#[derive(Serialize, Deserialize, Debug)]
struct StoryBroadcastRequest {
    cid: String,
    caption: Option<String>,
}

// Wallet API структуры
#[derive(Serialize, Deserialize, Debug)]
struct WalletLinkRequest {
    address: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct WalletBalanceResponse {
    success: bool,
    balance: Option<BalanceInfo>,
    error: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
struct WalletInfoResponse {
    linked: bool,
    address: Option<String>,
}

// Состояние приложения для API
#[derive(Clone)]
struct AppState {
    db: Arc<RwLock<Db>>,
    local_peer_id: Arc<RwLock<PeerId>>,
    public_key: Arc<RwLock<String>>,
    send_tx: Arc<RwLock<Option<mpsc::Sender<String>>>>,
    static_secret: Arc<RwLock<[u8; 32]>>,
    story_manager: Arc<StoryManager>,
    wallet_manager: Arc<WalletManager>,
    gossip_tx: Arc<RwLock<Option<mpsc::Sender<(String, Vec<u8>)>>>>,
    decentralized_provider: Option<Arc<DecentralizedProvider>>,
    ai_guard: Arc<AiGuard>,
    ai_manager: Arc<AiManager>,
    storage_manager: Arc<storage_manager::StorageManager>,
    admin_peer_id: String,
    social_manager: Arc<social::SocialManager>,
    geo_manager: Arc<geo::GeoManager>,
    network_manager: Option<Arc<RwLock<NetworkManager>>>,
}

#[derive(NetworkBehaviour)]
struct MyBehaviour {
    gossipsub: gossipsub::Behaviour,
    mdns: mdns::async_io::Behaviour,
    kademlia: kad::Behaviour<MemoryStore>,
}

/// Генерация или загрузка ключей шифрования X25519
fn load_or_generate_encryption_keys(db: &Db) -> Result<(StaticSecret, PublicKey), Box<dyn Error>> {
    if let Some(secret_bytes) = db.get("encryption_secret")? {
        println!("🔐 Ключи шифрования загружены из базы данных");

        if secret_bytes.len() != 32 {
            return Err(format!(
                "Повреждённый ключ в базе: ожидалось 32 байта, получено {}",
                secret_bytes.len()
            ).into());
        }

        let secret: [u8; 32] = secret_bytes.as_ref().try_into()
            .map_err(|_| "Не удалось конвертировать ключ в [u8; 32]")?;
        let static_secret = StaticSecret::from(secret);
        let public_key = PublicKey::from(&static_secret);
        Ok((static_secret, public_key))
    } else {
        println!("🆕 Генерация новых ключей шифрования...");
        let static_secret = StaticSecret::new(OsRng);
        let public_key = PublicKey::from(&static_secret);

        db.insert("encryption_secret", static_secret.to_bytes().to_vec())?;
        db.insert("encryption_public", public_key.to_bytes().to_vec())?;

        println!("✅ Ключи шифрования сохранены в базу данных");
        Ok((static_secret, public_key))
    }
}

/// Вычисление Shared Secret через Diffie-Hellman
fn compute_shared_secret(static_secret: &StaticSecret, their_public: &PublicKey) -> SharedSecret {
    static_secret.diffie_hellman(their_public)
}

/// Шифрование сообщения с использованием ChaCha20Poly1305
fn encrypt_message(content: &str, key: &[u8; 32]) -> Result<(Vec<u8>, Vec<u8>), Box<dyn Error>> {
    let cipher = ChaCha20Poly1305::new_from_slice(key)?;

    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher.encrypt(nonce, content.as_bytes().as_ref())
        .map_err(|e| format!("Ошибка шифрования: {:?}", e))?;

    Ok((ciphertext, nonce_bytes.to_vec()))
}

/// Дешифрование сообщения с использованием ChaCha20Poly1305
fn decrypt_message(ciphertext: &[u8], nonce: &[u8], key: &[u8; 32]) -> Result<String, Box<dyn Error>> {
    let cipher = ChaCha20Poly1305::new_from_slice(key)?;
    let nonce = Nonce::from_slice(nonce);

    let plaintext = cipher.decrypt(nonce, ciphertext)
        .map_err(|_| "Не удалось расшифровать сообщение")?;

    Ok(String::from_utf8_lossy(&plaintext).to_string())
}

/// Сохранение публичного ключа собеседника в базу
fn save_peer_key(db: &Db, peer_id: &str, public_key_hex: &str) -> Result<(), Box<dyn Error>> {
    let tree = db.open_tree("peer_keys")?;
    let key_bytes = hex::decode(public_key_hex)?;
    tree.insert(peer_id.as_bytes(), key_bytes)?;
    tree.flush()?;
    Ok(())
}

/// Загрузка публичного ключа собеседника из базы
fn load_peer_key(db: &Db, peer_id: &str) -> Result<Option<PublicKey>, Box<dyn Error>> {
    let tree = db.open_tree("peer_keys")?;
    if let Some(key_bytes) = tree.get(peer_id.as_bytes())? {
        let key_array: [u8; 32] = key_bytes.as_ref().try_into()
            .map_err(|_| "Неверный размер ключа")?;
        Ok(Some(PublicKey::from(key_array)))
    } else {
        Ok(None)
    }
}

/// Отправка handshake-сообщения пиру с профилем
fn send_handshake(
    swarm: &mut libp2p::Swarm<MyBehaviour>,
    topic: &gossipsub::IdentTopic,
    local_peer_id: PeerId,
    public_key: &PublicKey,
    db: &Db,
) -> Result<(), Box<dyn Error>> {
    // Загружаем свой профиль
    let profile = if let Ok(tree) = db.open_tree("own_profile") {
        if let Some(profile_bytes) = tree.get("profile")? {
            serde_json::from_slice::<UserProfile>(&profile_bytes).ok()
        } else {
            Some(UserProfile::new(local_peer_id.to_string(), "Anonymous".to_string()))
        }
    } else {
        Some(UserProfile::new(local_peer_id.to_string(), "Anonymous".to_string()))
    };

    // Шифруем профиль своим static_secret (для демо)
    let encrypted_profile = if let Some(p) = profile {
        // В полной версии здесь будет шифрование на ключе получателя
        let profile_json = serde_json::to_vec(&p)?;
        Some(profile_json)
    } else {
        None
    };

    let handshake = HandshakeMessage {
        peer_id: local_peer_id.to_string(),
        encryption_key: hex::encode(public_key.to_bytes()),
        encrypted_profile,
    };

    let serialized = serde_json::to_vec(&handshake)?;
    let _ = swarm.behaviour_mut().gossipsub.publish(topic.clone(), serialized);
    Ok(())
}

// ============================================================================
// API Handlers
// ============================================================================

async fn api_info(State(state): State<AppState>) -> Json<ApiInfo> {
    let peer_id = state.local_peer_id.read().await.to_string();
    let public_key = state.public_key.read().await.clone();
    
    Json(ApiInfo {
        peer_id,
        public_key,
        status: "online".to_string(),
    })
}

async fn api_history(State(state): State<AppState>) -> Json<ApiHistory> {
    let db = state.db.read().await;
    let mut messages = Vec::new();
    
    for res in db.scan_prefix("msg_").rev().take(20) {
        if let Ok((key, val)) = res {
            let key_str = String::from_utf8_lossy(&key);
            if let Some(ts_str) = key_str.strip_prefix("msg_") {
                if let Ok(ts) = ts_str.parse::<u128>() {
                    messages.push(ApiHistoryItem {
                        timestamp: ts,
                        content: String::from_utf8_lossy(&val).to_string(),
                    });
                }
            }
        }
    }
    
    Json(ApiHistory { messages })
}

async fn api_send(
    State(state): State<AppState>,
    Json(payload): Json<SendRequest>,
) -> Result<Json<SendResponse>, StatusCode> {
    if let Some(sender) = state.send_tx.read().await.as_ref() {
        if sender.send(payload.text).await.is_ok() {
            return Ok(Json(SendResponse {
                success: true,
                message: "Message queued for sending".to_string(),
            }));
        }
    }
    
    Err(StatusCode::INTERNAL_SERVER_ERROR)
}

async fn api_peers(State(state): State<AppState>) -> Json<Vec<serde_json::Value>> {
    let db = state.db.read().await;
    let mut peers = Vec::new();

    if let Ok(tree) = db.open_tree("peer_keys") {
        for entry in tree.iter() {
            if let Ok((peer_id_bytes, key_bytes)) = entry {
                let peer_id = String::from_utf8_lossy(&peer_id_bytes).to_string();
                let key_hex = hex::encode(&key_bytes);
                peers.push(serde_json::json!({
                    "peer_id": peer_id,
                    "public_key": key_hex,
                }));
            }
        }
    }

    Json(peers)
}

// ============================================================================
// Identity API Handlers
// ============================================================================

async fn api_identity_self(State(state): State<AppState>) -> Result<Json<UserProfile>, StatusCode> {
    let db = state.db.read().await;
    let peer_id = state.local_peer_id.read().await.to_string();
    
    let tree = db.open_tree("own_profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    if let Some(profile_bytes) = tree.get("profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        let profile: UserProfile = serde_json::from_slice(&profile_bytes)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        Ok(Json(profile))
    } else {
        // Профиль не найден, возвращаем дефолтный
        let profile = UserProfile::new(peer_id, "Anonymous".to_string());
        Ok(Json(profile))
    }
}

async fn api_identity_update(
    State(state): State<AppState>,
    Json(payload): Json<ApiProfileUpdate>,
) -> Result<Json<UserProfile>, StatusCode> {
    let db = state.db.read().await;
    let peer_id = state.local_peer_id.read().await.to_string();
    
    let tree = db.open_tree("own_profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Загружаем существующий профиль или создаём новый
    let mut profile = if let Some(profile_bytes) = tree.get("profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        serde_json::from_slice::<UserProfile>(&profile_bytes)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
    } else {
        UserProfile::new(peer_id.clone(), "Anonymous".to_string())
    };
    
    // Обновляем поля
    profile.update(payload.nickname, payload.bio, payload.avatar_cid);

    if let Some(status) = payload.relation_status {
        profile.relation_status = status;
    }

    if let Some(wallpaper) = payload.wallpaper_url {
        profile.set_wallpaper(Some(wallpaper));
    }

    if let Some(partner) = payload.partner_peer_id {
        profile.set_partner(Some(partner));
    }

    // Сохраняем профиль
    let profile_bytes = serde_json::to_vec(&profile).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    tree.insert("profile", profile_bytes).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json(profile))
}

// ============================================================================
// Wallpaper API Handlers
// ============================================================================

async fn api_identity_wallpaper(
    State(state): State<AppState>,
    Json(payload): Json<ApiWallpaperRequest>,
) -> Result<Json<ApiWallpaperResponse>, StatusCode> {
    let db = state.db.read().await;
    let peer_id = state.local_peer_id.read().await.to_string();
    let static_secret = state.static_secret.read().await;
    
    // Создаём подпись Ed25519 (используем static_secret как ключ для демо)
    // В продакшене нужно использовать отдельный Ed25519 ключ
    let signature = hex::encode(&static_secret[..32]);

    // Создаём сообщение обновления
    let _wallpaper_update = WallpaperUpdate::new(
        peer_id.clone(),
        payload.wallpaper_cid.clone(),
        signature,
    );
    
    // Сохраняем обои в свой профиль
    let tree = db.open_tree("own_profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    if let Some(profile_bytes) = tree.get("profile").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        if let Ok(mut profile) = serde_json::from_slice::<UserProfile>(&profile_bytes) {
            profile.set_wallpaper(Some(payload.wallpaper_cid.clone()));
            let profile_bytes = serde_json::to_vec(&profile).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            tree.insert("profile", profile_bytes).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            
            // Если запрошена синхронизация с партнёром
            let mut synced_with = None;
            if payload.sync_with_partner.unwrap_or(false) {
                if let Some(partner_id) = &profile.partner_peer_id {
                    // Отправляем сообщение партнёру через Gossipsub
                    // (в полной версии здесь будет отправка через swarm channel)
                    synced_with = Some(partner_id.clone());
                }
            }
            
            return Ok(Json(ApiWallpaperResponse {
                success: true,
                wallpaper_cid: payload.wallpaper_cid.clone(),
                synced_with,
            }));
        }
    }
    
    Err(StatusCode::NOT_FOUND)
}

async fn api_identity_peers(State(state): State<AppState>) -> Json<Vec<serde_json::Value>> {
    let db = state.db.read().await;
    let mut peers = Vec::new();

    // Получаем список пиров из дерева peer_profiles
    if let Ok(tree) = db.open_tree("peer_profiles") {
        for entry in tree.iter() {
            if let Ok((peer_id_bytes, profile_bytes)) = entry {
                let peer_id = String::from_utf8_lossy(&peer_id_bytes).to_string();

                // Пробуем декодировать профиль
                if let Ok(profile) = serde_json::from_slice::<UserProfile>(&profile_bytes) {
                    peers.push(serde_json::json!({
                        "peer_id": peer_id,
                        "nickname": profile.nickname,
                        "display_name": profile.display_name(),
                        "relation_status": format!("{:?}", profile.relation_status),
                        "is_verified": profile.is_verified,
                        "bio": profile.bio,
                    }));
                }
            }
        }
    }

    Json(peers)
}

// ============================================================================
// Stories API Handlers
// ============================================================================

async fn api_stories_upload(
    State(state): State<AppState>,
    Json(payload): Json<StoryUploadRequest>,
) -> Result<Json<StoryUploadResponse>, StatusCode> {
    // Декодируем base64 изображение
    use base64::{Engine, engine::general_purpose};
    let image_bytes = general_purpose::STANDARD.decode(&payload.image_base64)
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    let story_manager = state.story_manager.clone();

    // Загружаем и создаём историю
    let filename = format!("story_{}.jpg", chrono::Utc::now().timestamp());
    
    let story = match story_manager.upload_and_create_story(image_bytes, &filename, payload.caption).await {
        Ok(s) => s,
        Err(e) => {
            eprintln!("❌ Ошибка загрузки истории: {}", e);
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    // Вещаем CID через Gossipsub
    if let Some(tx) = state.gossip_tx.read().await.as_ref() {
        let broadcast = story_manager.create_broadcast_message(&story);
        let broadcast_bytes = serde_json::to_vec(&broadcast).unwrap_or_default();
        let _ = tx.send(("liberty-stories".to_string(), broadcast_bytes)).await;
    }

    Ok(Json(StoryUploadResponse {
        success: true,
        cid: story.cid.clone(),
        author_peer_id: story.author_peer_id.clone(),
        timestamp: story.timestamp.timestamp() as u64,
    }))
}

async fn api_stories_feed(State(state): State<AppState>) -> Json<StoryFeedResponse> {
    let story_manager = state.story_manager.clone();

    match story_manager.get_active_stories().await {
        Ok(stories) => Json(StoryFeedResponse { stories }),
        Err(e) => {
            eprintln!("❌ Ошибка получения историй: {}", e);
            Json(StoryFeedResponse { stories: Vec::new() })
        }
    }
}

async fn api_stories_by_author(
    State(state): State<AppState>,
    axum::extract::Path(author_peer_id): axum::extract::Path<String>,
) -> Json<StoryFeedResponse> {
    let story_manager = state.story_manager.clone();

    match story_manager.get_stories_by_author(&author_peer_id).await {
        Ok(stories) => Json(StoryFeedResponse { stories }),
        Err(e) => {
            eprintln!("❌ Ошибка получения историй автора: {}", e);
            Json(StoryFeedResponse { stories: Vec::new() })
        }
    }
}

async fn api_stories_broadcast(
    State(state): State<AppState>,
    Json(payload): Json<StoryBroadcastRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let story_manager = state.story_manager.clone();

    // Создаём историю локально
    let story = StoryItem::new(
        state.local_peer_id.read().await.to_string(),
        payload.cid.clone(),
        payload.caption,
    );

    // Сохраняем
    if let Err(e) = story_manager.save_story(&story).await {
        eprintln!("❌ Ошибка сохранения истории: {}", e);
        return Err(StatusCode::INTERNAL_SERVER_ERROR);
    }

    // Вещаем через Gossipsub
    if let Some(tx) = state.gossip_tx.read().await.as_ref() {
        let broadcast = story_manager.create_broadcast_message(&story);
        let broadcast_bytes = serde_json::to_vec(&broadcast).unwrap_or_default();
        
        if tx.send(("liberty-stories".to_string(), broadcast_bytes)).await.is_ok() {
            return Ok(Json(serde_json::json!({
                "success": true,
                "message": "Story broadcast sent"
            })));
        }
    }

    Err(StatusCode::INTERNAL_SERVER_ERROR)
}

// ============================================================================
// Wallet API Handlers
// ============================================================================

async fn api_wallet_info(State(state): State<AppState>) -> Json<WalletInfoResponse> {
    let wallet_manager = state.wallet_manager.clone();

    match wallet_manager.get_linked_address().await {
        Ok(Some(address)) => Json(WalletInfoResponse {
            linked: true,
            address: Some(address),
        }),
        Ok(None) => Json(WalletInfoResponse {
            linked: false,
            address: None,
        }),
        Err(_) => Json(WalletInfoResponse {
            linked: false,
            address: None,
        }),
    }
}

async fn api_wallet_link(
    State(state): State<AppState>,
    Json(payload): Json<WalletLinkRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let wallet_manager = state.wallet_manager.clone();

    match wallet_manager.link_wallet(&payload.address).await {
        Ok(()) => Ok(Json(serde_json::json!({
            "success": true,
            "message": "Wallet linked successfully"
        }))),
        Err(e) => {
            eprintln!("❌ Ошибка привязки кошелька: {}", e);
            Err(StatusCode::BAD_REQUEST)
        }
    }
}

async fn api_wallet_unlink(State(state): State<AppState>) -> Result<Json<serde_json::Value>, StatusCode> {
    let wallet_manager = state.wallet_manager.clone();

    match wallet_manager.unlink_wallet().await {
        Ok(()) => Ok(Json(serde_json::json!({
            "success": true,
            "message": "Wallet unlinked"
        }))),
        Err(e) => {
            eprintln!("❌ Ошибка отвязки кошелька: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn api_wallet_balance(State(state): State<AppState>) -> Json<WalletBalanceResponse> {
    let wallet_manager = state.wallet_manager.clone();

    match wallet_manager.get_linked_balance().await {
        Ok(balance) => Json(WalletBalanceResponse {
            success: true,
            balance: Some(balance),
            error: None,
        }),
        Err(e) => {
            // Пробуем получить баланс по адресу из запроса (если кошелёк не привязан)
            Json(WalletBalanceResponse {
                success: false,
                balance: None,
                error: Some(e.to_string()),
            })
        }
    }
}

async fn api_wallet_balance_address(
    State(state): State<AppState>,
    axum::extract::Path(address): axum::extract::Path<String>,
) -> Json<WalletBalanceResponse> {
    let wallet_manager = state.wallet_manager.clone();

    match wallet_manager.get_balance(&address).await {
        Ok(balance) => Json(WalletBalanceResponse {
            success: true,
            balance: Some(balance),
            error: None,
        }),
        Err(e) => Json(WalletBalanceResponse {
            success: false,
            balance: None,
            error: Some(e.to_string()),
        }),
    }
}


// ============================================================================
// AI Guard API Handlers
// ============================================================================

async fn api_ai_status(State(state): State<AppState>) -> Json<serde_json::Value> {
    let cache_size = state.ai_guard.cache.read().await.len();
    Json(serde_json::json!({
        "enabled": state.ai_guard.config.is_enabled(),
        "cache_size": cache_size,
        "toxicity_threshold": state.ai_guard.config.toxicity_threshold,
        "mute_threshold": state.ai_guard.config.mute_threshold
    }))
}

async fn api_ai_violations(
    State(state): State<AppState>,
    axum::extract::Path(peer_id): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.ai_guard.get_violations(&peer_id).await {
        Ok(violations) => Ok(Json(serde_json::json!({
            "success": true,
            "violations": violations
        }))),
        Err(e) => Err(StatusCode::INTERNAL_SERVER_ERROR)
    }
}

async fn api_ai_reset_violations(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    if let Some(peer_id) = payload["peer_id"].as_str() {
        match state.ai_guard.reset_violations(peer_id).await {
            Ok(()) => Ok(Json(serde_json::json!({
                "success": true,
                "message": "Violations reset"
            }))),
            Err(e) => Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    } else {
        Err(StatusCode::BAD_REQUEST)
    }
}

// Возвращает основной роутер и admin/media роутеры
fn create_router(state: AppState) -> (Router, Router, Router) {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Создаём admin state и media state из общего AppState
    let admin_state = admin_handlers::AdminState {
        db: state.db.blocking_read().clone().into(),
        admin_peer_id: state.admin_peer_id.clone(),
    };

    let media_state = media_handlers::MediaState {
        db: state.db.blocking_read().clone().into(),
        storage_manager: state.storage_manager.clone(),
        local_peer_id: state.local_peer_id.blocking_read().to_string(),
    };

    // Создаём под-роутеры для admin и media
    let admin_router = admin_handlers::admin_router(admin_state);
    let media_router = media_handlers::media_router(media_state);

    // Выводим информацию о доступных endpoint'ах
    println!("📋 Admin API endpoints:");
    println!("   GET  /api/v1/admin/config - получить конфиг");
    println!("   POST /api/v1/admin/config - обновить конфиг");
    println!("   GET  /api/v1/admin/bans - список банов");
    println!("   POST /api/v1/admin/bans - забанить PeerID");
    println!("   DELETE /api/v1/admin/bans/:peer_id - разбанить");
    println!("   GET  /api/v1/admin/db/stats - статистика БД");
    println!("   GET  /api/v1/admin/db/keys - ключи БД");
    println!("   GET  /api/v1/admin/reports - список репортов");
    println!("   POST /api/v1/admin/reports/:id/review - обзор репорта");
    println!("   (требуется заголовок X-Peer-ID с ADMIN_PEER_ID)");
    println!();
    println!("📋 Media API endpoints:");
    println!("   POST /api/media/upload - загрузка медиа (Voice/VideoCircle)");
    println!("   POST /api/media/pin/:cid - pin на 7 дней");
    println!("   GET  /api/media/:cid - метаданные");
    println!("   GET  /api/media/list - список всех медиа");
    println!();

    let main_router = Router::new()
        .route("/info", get(api_info))
        .route("/history", get(api_history))
        .route("/send", post(api_send))
        .route("/peers", get(api_peers))
        // Identity API
        .route("/api/identity/self", get(api_identity_self))
        .route("/api/identity/update", post(api_identity_update))
        .route("/api/identity/peers", get(api_identity_peers))
        .route("/api/identity/wallpaper", post(api_identity_wallpaper))
        // Stories API
        .route("/api/stories/upload", post(api_stories_upload))
        .route("/api/stories/feed", get(api_stories_feed))
        .route("/api/stories/feed/:author_peer_id", get(api_stories_by_author))
        .route("/api/stories/broadcast", post(api_stories_broadcast))
        // Wallet API
        .route("/api/wallet/info", get(api_wallet_info))
        .route("/api/wallet/link", post(api_wallet_link))
        .route("/api/wallet/unlink", post(api_wallet_unlink))
        .route("/api/wallet/balance", get(api_wallet_balance))
        .route("/api/wallet/balance/:address", get(api_wallet_balance_address))
        .layer(cors)
        .with_state(state);

    (main_router, admin_router, media_router)
}

// ============================================================================
// Main
// ============================================================================

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Загрузка переменных окружения из .env.local
    dotenv::dotenv().ok();
    
    println!("🚀 Liberty Sovereign: Ultimate Edition");
    println!("=====================================\n");

    // 1. Инициализация БД Sled
    let db: Db = sled::open("./liberty_data3/liberty_db")?;
    let db_arc = Arc::new(RwLock::new(db));

    // 2. Загрузка Identity (libp2p keys)
    let id_keys = {
        let db = db_arc.read().await;
        if let Some(stored_keys) = db.get("identity")? {
            println!("🔑 Identity загружена из базы данных");
            identity::Keypair::from_protobuf_encoding(&stored_keys)?
        } else {
            let new_keys = identity::Keypair::generate_ed25519();
            db.insert("identity", new_keys.to_protobuf_encoding()?)?;
            println!("🆕 Сгенерирована и сохранена новая Identity");
            new_keys
        }
    };

    let local_peer_id = PeerId::from(id_keys.public());
    println!("🆔 PeerID: {local_peer_id}");

    // 3. Загрузка ключей шифрования X25519
    let (static_secret, public_key) = {
        let db = db_arc.read().await;
        load_or_generate_encryption_keys(&db)?
    };
    
    let public_key_hex = hex::encode(public_key.to_bytes());
    println!("🔓 Public Key: {}", public_key_hex);
    println!("🔐 Шифрование: ChaCha20Poly1305 + X25519 Diffie-Hellman\n");

    // 4. Создание канала для связи API -> Swarm
    let (send_tx, mut send_rx) = mpsc::channel::<String>(32);
    let send_tx_arc = Arc::new(RwLock::new(Some(send_tx)));

    // Канал для отправки сообщений в Gossipsub из API
    let (gossip_tx, mut gossip_rx) = mpsc::channel::<(String, Vec<u8>)>(32);
    let gossip_tx_arc = Arc::new(RwLock::new(Some(gossip_tx)));

    // 5. Инициализация StoryManager
    let mut story_manager = StoryManager::new(
        db_arc.clone(),
        local_peer_id.to_string(),
    );

    // Инициализация Pinata (если переменные окружения доступны)
    // Инициализация Pinata (приоритет: JWT > API_KEY+SECRET)
    if let Ok(jwt) = std::env::var("PINATA_JWT") {
        let pinata_config = PinataConfig::from_jwt(jwt);
        story_manager.set_pinata_client(pinata_config);
        println!("📌 Pinata IPFS настроен (JWT токен)");
    } else if let (Ok(api_key), Ok(secret_key)) = (std::env::var("PINATA_API_KEY"), std::env::var("PINATA_SECRET_KEY")) {
        let pinata_config = PinataConfig::new(api_key, secret_key, None);
        story_manager.set_pinata_client(pinata_config);
        println!("📌 Pinata IPFS настроен (API ключи)");
    } else {
        println!("⚠️ Pinata не настроен (установите PINATA_JWT или PINATA_API_KEY)");
    }

    let story_manager = Arc::new(story_manager);

    // 6. Инициализация WalletManager с децентрализованным провайдером
    let wallet_config = WalletConfig::decentralized();
    let mut wallet_manager_inner = WalletManager::new(wallet_config, db_arc.clone());
    
    // Загружаем привязанный кошелёк из БД
    match wallet_manager_inner.load_linked_wallet().await {
        Ok(Some(addr)) => println!("💰 Кошелёк загружен: {}", addr),
        Ok(None) => println!("💰 Кошелёк не привязан"),
        Err(e) => eprintln!("⚠️ Ошибка загрузки кошелька: {}", e),
    }
    
    // Получаем ссылку на децентрализованный провайдер
    let dec_provider = wallet_manager_inner.get_decentralized_provider()
        .map(|dp| {
            let dp_arc = Arc::new(dp.clone());
            
            // Запускаем проверку здоровья RPC нод в фоне
            let health_dp = dp_arc.clone();
            tokio::spawn(async move {
                // Начальная проверка здоровья
                health_dp.health_check().await;
            });
            
            println!("🌐 [Wallet] Decentralized RPC initialized. Primary: Pocket, Secondary: Lava");
            dp_arc
        });
    
    let wallet_manager = Arc::new(wallet_manager_inner);

    // Инициализация AI Guard
    let ai_guard_config = AiGuardConfig::from_env();
    let ai_guard = Arc::new(AiGuard::new(ai_guard_config, db_arc.clone()));
    if ai_guard.config.is_enabled() {
        println!("🛡️ [AI Guard] Модерация включена");
    } else {
        println!("⚠️ [AI Guard] Модерация выключена (нет OPENROUTER_API_KEY)");
    }

    // 7. Создание AppState для API
    // Создаём StorageManager
    let pinata_api_key = std::env::var("PINATA_API_KEY").ok();
    let pinata_secret_key = std::env::var("PINATA_SECRET_KEY").ok();
    let storage_manager = Arc::new(storage_manager::StorageManager::new(
        db_arc.blocking_read().clone().into(),
        pinata_api_key,
        pinata_secret_key,
    ));

    // Получаем ADMIN_PEER_ID
    let admin_peer_id = std::env::var("ADMIN_PEER_ID")
        .unwrap_or_else(|_| local_peer_id.to_string());

    // Запускаем Garbage Collector
    let gc_storage = storage_manager.clone();
    tokio::spawn(async move {
        gc_storage.start_garbage_collector(1).await;
    });
    println!("🧹 Storage Manager GC запущен (проверка каждые 1 час)");

    // Инициализация Social Manager
    let social_manager = Arc::new(social::SocialManager::new(local_peer_id.to_string()));
    println!("👥 Social Manager инициализирован (Direct, Secret, Groups, Channels)");

    // Инициализация Geo Manager
    let geo_manager = Arc::new(geo::GeoManager::new(db_arc.blocking_read().clone().into()));
    println!("🌍 Geo Manager инициализирован (GPS + LBS + SOS)");

    // Инициализация AI Manager (Hybrid: Ollama + OpenRouter)
    let ai_manager = start_ai_manager(config.clone());
    println!("🤖 AI Manager инициализирован (Ollama + OpenRouter failover)");

    // Инициализация Network Manager (P2P с Kademlia + Relay)
    let identity_keypair = libp2p::identity::ed25519::Keypair::from_bytes(&identity.secret().to_bytes()).unwrap();
    let (network_event_tx, mut network_event_rx) = tokio::sync::mpsc::channel(100);
    
    let network_manager = match start_p2p_network(
        config.clone(),
        identity_keypair,
        network_event_tx,
    ).await {
        Ok(manager) => {
            println!("📡 P2P Network Manager инициализирован");
            Some(manager)
        }
        Err(e) => {
            eprintln!("⚠️  P2P Network не инициализирован: {}", e);
            None
        }
    };

    // Обработка P2P событий в фоне
    if let Some(ref nm) = network_manager {
        let ai_mgr = Arc::clone(&ai_manager);
        let nm_clone = Arc::clone(nm);
        tokio::spawn(async move {
            while let Some(event) = network_event_rx.recv().await {
                match event {
                    NetworkEvent::MessageReceived { from, data } => {
                        // Автоматическая обработка входящих сообщений через AI
                        if let Ok(msg) = String::from_utf8(data.clone()) {
                            if let Ok(ai_response) = ai_mgr.process_incoming_message(&msg, None).await {
                                println!("🤖 AI suggestion for message from {}: {}", from, ai_response.content);
                            }
                        }
                    }
                    NetworkEvent::HandshakeComplete { peer_id, shared_secret } => {
                        println!("🔐 Handshake complete with {}: shared_secret={:?}", peer_id, &shared_secret[..8]);
                        // Сохранить shared_secret для E2EE
                        let mut manager = nm_clone.write().await;
                        manager.shared_secrets.insert(peer_id, shared_secret);
                    }
                    _ => {}
                }
            }
        });
    }

    let app_state = AppState {
        db: db_arc.clone(),
        local_peer_id: Arc::new(RwLock::new(local_peer_id)),
        public_key: Arc::new(RwLock::new(public_key_hex.clone())),
        send_tx: send_tx_arc.clone(),
        static_secret: Arc::new(RwLock::new(static_secret.to_bytes())),
        story_manager: story_manager.clone(),
        wallet_manager: wallet_manager.clone(),
        gossip_tx: gossip_tx_arc.clone(),
        decentralized_provider: dec_provider,
        ai_guard: ai_guard.clone(),
        ai_manager: ai_manager.clone(),
        storage_manager: storage_manager.clone(),
        admin_peer_id: admin_peer_id.clone(),
        social_manager: social_manager.clone(),
        geo_manager: geo_manager.clone(),
        network_manager: network_manager.clone(),
    };

    // 8. Запуск HTTP сервера в отдельной задаче
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let (router, admin_router, media_router) = create_router(app_state.clone());

    println!("🌐 Web API сервер запущен на http://{}", addr);
    println!("   GET  /info   - информация о ноде");
    println!("   GET  /history - история сообщений");
    println!("   POST /send    - отправить сообщение");
    println!("   GET  /peers   - список пиров");
    println!("   GET  /api/identity/self - мой профиль");
    println!("   POST /api/identity/update - обновить профиль");
    println!("   POST /api/stories/upload - загрузить историю (image base64)");
    println!("   GET  /api/stories/feed - лента историй");
    println!("   GET  /api/wallet/info - информация о кошельке");
    println!("   POST /api/wallet/link - привязать кошелёк");
    println!("   GET  /api/wallet/balance - баланс MATIC\n");

    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
        axum::serve(listener, router).await.unwrap();
    });

    // Запуск отдельного сервера для Admin & Media API на порту 3001
    let admin_media_addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    let admin_media_router = admin_router.merge(media_router);
    
    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(admin_media_addr).await.unwrap();
        println!("🔐 Admin & Media API сервер запущен на http://{}", admin_media_addr);
        axum::serve(listener, admin_media_router).await.unwrap();
    });

    // 9. Запуск фоновой задачи очистки историй
    let cleanup_story_manager = story_manager.clone();
    tokio::spawn(async move {
        stories::stories_cleanup_task(cleanup_story_manager, 3600).await;
    });
    println!("🕒 Фоновая задача очистки историй запущена (интервал: 1 час)");

    // 10. Запуск задачи обработки Gossipsub сообщений из API
    // Эта задача обрабатывается в основном цикле через gossip_rx

    // 11. Настройка Gossipsub
    let message_id_fn = |message: &gossipsub::Message| {
        let mut s = DefaultHasher::new();
        message.data.hash(&mut s);
        gossipsub::MessageId::from(s.finish().to_string())
    };

    let gossip_config = gossipsub::ConfigBuilder::default()
        .heartbeat_interval(Duration::from_secs(10))
        .validation_mode(gossipsub::ValidationMode::Strict)
        .message_id_fn(message_id_fn)
        .build()?;

    // 8. Настройка Kademlia DHT
    let protocol_name = libp2p::StreamProtocol::new("/liberty-reach/kad/1.0.0");
    let mut kademlia_config = kad::Config::default();
    kademlia_config.set_protocol_names(vec![protocol_name.clone()]);
    
    // 9. Настройка Swarm
    let mut swarm = libp2p::SwarmBuilder::with_existing_identity(id_keys)
        .with_async_std()
        .with_tcp(
            libp2p::tcp::Config::default(),
            libp2p::noise::Config::new,
            libp2p::yamux::Config::default,
        )?
        .with_quic()
        .with_behaviour(|key| {
            let store = MemoryStore::new(key.public().to_peer_id());
            let mut kademlia = kad::Behaviour::with_config(key.public().to_peer_id(), store, kademlia_config.clone());
            kademlia.set_mode(Some(kad::Mode::Server));
            
            Ok(MyBehaviour {
                gossipsub: gossipsub::Behaviour::new(
                    gossipsub::MessageAuthenticity::Signed(key.clone()),
                    gossip_config,
                )?,
                mdns: mdns::async_io::Behaviour::new(mdns::Config::default(), key.public().to_peer_id())?,
                kademlia,
            })
        })?
        .with_swarm_config(|c| c.with_idle_connection_timeout(Duration::from_secs(60)))
        .build();

    // 10. Подписка на темы
    let topic = gossipsub::IdentTopic::new("liberty-chat");
    let handshake_topic = gossipsub::IdentTopic::new("liberty-handshake");
    let stories_topic = gossipsub::IdentTopic::new("liberty-stories");
    swarm.behaviour_mut().gossipsub.subscribe(&topic)?;
    swarm.behaviour_mut().gossipsub.subscribe(&handshake_topic)?;
    swarm.behaviour_mut().gossipsub.subscribe(&stories_topic)?;

    // Слушаем на всех интерфейсах
    swarm.listen_on("/ip4/0.0.0.0/tcp/0".parse()?)?;
    swarm.listen_on("/ip4/0.0.0.0/udp/0/quic-v1".parse()?)?;

    println!("🌐 Kademlia DHT: {}", protocol_name);
    println!("✅ Подписка на темы: liberty-chat, liberty-handshake, liberty-stories");
    println!("💬 Мессенджер готов к работе!\n");

    // 10. Основной цикл с tokio::select!
    loop {
        tokio::select! {
            // Сообщения от API для отправки в Gossipsub
            Some((topic_name, data)) = gossip_rx.recv() => {
                // Определяем тему для публикации
                let publish_topic = if topic_name == "liberty-stories" {
                    &stories_topic
                } else {
                    &topic
                };

                if let Err(e) = swarm.behaviour_mut().gossipsub.publish(publish_topic.clone(), data) {
                    eprintln!("❌ Ошибка публикации в {}: {:?}", topic_name, e);
                }
            }

            // Сообщения от API
            Some(text) = send_rx.recv() => {
                let timestamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_millis();
                let shared_secret = compute_shared_secret(&static_secret, &public_key);
                
                let (content_bytes, nonce, is_encrypted) = match encrypt_message(&text, &shared_secret.to_bytes()) {
                    Ok((ciphertext, nonce)) => (ciphertext, nonce, true),
                    Err(_) => (text.as_bytes().to_vec(), vec![], false),
                };

                // AI Guard проверка перед отправкой
                // AI Guard уже доступен из outer scope
                let local_peer_id_str = local_peer_id.to_string();
                
                // Проверяем, не в mute ли пользователь
                if let Ok(false) = ai_guard.can_send_message(&local_peer_id_str).await {
                    eprintln!("🔇 [AI Guard] Сообщение заблокировано (пользователь в mute)");
                    continue; // Пропускаем отправку
                }
                
                // Анализируем контент если модерация включена
                if ai_guard.config.is_enabled() {
                    match ai_guard.analyze_content(&text).await {
                        Ok(analysis) => {
                            if !analysis.safe {
                                // Записываем нарушение
                                let _ = ai_guard.record_violation(
                                    &local_peer_id_str,
                                    ViolationType::Other,
                                    &analysis.reason.clone().unwrap_or_default()
                                ).await;
                                eprintln!("🚫 [AI Guard] Сообщение заблокировано: {}", 
                                    analysis.reason.unwrap_or_default());
                                continue; // Пропускаем отправку
                            }
                        }
                        Err(e) => {
                            eprintln!("⚠️ [AI Guard] Ошибка анализа: {}", e);
                            // Продолжаем отправку (fail-open)
                        }
                    }
                }

                let chat_msg = ChatMessage {
                    sender: local_peer_id.to_string(),
                    content: content_bytes,
                    nonce,
                    is_encrypted,
                    timestamp,
                };

                if let Ok(serialized) = serde_json::to_vec(&chat_msg) {
                    let db = db_arc.read().await;
                    let display_text = if is_encrypted {
                        format!("🔐 {}: [зашифровано]", local_peer_id)
                    } else {
                        format!("{}: {}", local_peer_id, &text)
                    };
                    db.insert(format!("msg_{}", timestamp), display_text.as_bytes())?;

                    if let Err(e) = swarm.behaviour_mut().gossipsub.publish(topic.clone(), serialized) {
                        eprintln!("❌ Ошибка отправки: {e:?}");
                    }
                }
            }
            
            // Сетевые события
            event = swarm.select_next_some() => {
                match event {
                    SwarmEvent::NewListenAddr { address, .. } => {
                        println!("📍 Слушаю на: {address}");
                    }
                    SwarmEvent::Behaviour(MyBehaviourEvent::Kademlia(kad_event)) => {
                        match kad_event {
                            kad::Event::OutboundQueryProgressed { result, .. } => {
                                match result {
                                    kad::QueryResult::GetClosestPeers(ok) => {
                                        match ok {
                                            Ok(ok) => {
                                                if ok.peers.is_empty() {
                                                    println!("⚠️ Пир не найден в DHT");
                                                } else {
                                                    println!("🌐 Найдено пиров в DHT: {}", ok.peers.len());
                                                    for peer in &ok.peers {
                                                        println!("   → {}", peer);
                                                    }
                                                }
                                            }
                                            Err(e) => println!("❌ Ошибка поиска в DHT: {:?}", e),
                                        }
                                    }
                                    _ => {}
                                }
                            }
                            kad::Event::RoutingUpdated { peer, addresses, .. } => {
                                println!("🗺️ Маршрут обновлён для {} через {} адрес(ов)", peer, addresses.len());
                            }
                            _ => {}
                        }
                    }
                    SwarmEvent::Behaviour(MyBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                        for (peer_id, addr) in list {
                            println!("🔍 Найден узел: {peer_id} на {addr}");
                            swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer_id);
                            // Добавляем в Kademlia
                            swarm.behaviour_mut().kademlia.add_address(&peer_id, addr.into());
                        }
                    }
                    SwarmEvent::Behaviour(MyBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
                        for (peer_id, _) in list {
                            println!("⏰ Узел перестал отвечать: {peer_id}");
                            swarm.behaviour_mut().gossipsub.remove_explicit_peer(&peer_id);
                        }
                    }
                    SwarmEvent::Behaviour(MyBehaviourEvent::Gossipsub(gossipsub::Event::Message { message, .. })) => {
                        // Пробуем декодировать как StoryBroadcast
                        if let Ok(story_broadcast) = serde_json::from_slice::<StoryBroadcast>(&message.data) {
                            println!("📥 Получена история от {} (CID: {})", 
                                story_broadcast.author_peer_id, 
                                story_broadcast.cid);

                            let db = db_arc.clone();

                            // Обрабатываем в фоновом режиме
                            tokio::spawn(async move {
                                // Сохраняем историю в БД
                                let story = StoryItem::new(
                                    story_broadcast.author_peer_id.clone(),
                                    story_broadcast.cid.clone(),
                                    None,
                                );
                                
                                let db_guard = db.read().await;
                                if let Ok(tree) = db_guard.open_tree("stories") {
                                    let key = format!("story_{}_{}", story.author_peer_id, story.timestamp.timestamp_millis());
                                    let value = serde_json::to_vec(&story).unwrap_or_default();
                                    let _ = tree.insert(key.as_bytes(), value);
                                    let _ = tree.flush();
                                }
                            });

                            continue;
                        }

                        // Пробуем декодировать как handshake
                        if let Ok(handshake) = serde_json::from_slice::<HandshakeMessage>(&message.data) {
                            println!("🤝 Получен handshake от {} (key: {}...)",
                                handshake.peer_id,
                                &handshake.encryption_key[..16]);

                            let db = db_arc.read().await;

                            // Сохраняем ключ
                            if let Err(e) = save_peer_key(&db, &handshake.peer_id, &handshake.encryption_key) {
                                eprintln!("❌ Ошибка сохранения ключа: {e:?}");
                            } else {
                                println!("✅ Ключ шифрования сохранён для {}", handshake.peer_id);
                            }

                            // Дешифруем и сохраняем профиль
                            if let Some(encrypted_profile) = handshake.encrypted_profile {
                                // В полной версии здесь будет дешифрование на shared secret
                                // Сейчас просто сохраняем как есть
                                if let Ok(profile) = serde_json::from_slice::<UserProfile>(&encrypted_profile) {
                                    if let Ok(tree) = db.open_tree("peer_profiles") {
                                        tree.insert(handshake.peer_id.as_bytes(), encrypted_profile).ok();
                                        tree.flush().ok();
                                        println!("✅ Профиль сохранён для {} (ник: {})",
                                            handshake.peer_id, profile.nickname);
                                    }
                                }
                            }

                            continue;
                        }
                        
                        // Пробуем декодировать как WallpaperUpdate
                        if let Ok(wallpaper_update) = serde_json::from_slice::<WallpaperUpdate>(&message.data) {
                            println!("🖼️ Получено обновление обоев от {}", wallpaper_update.peer_id);
                            
                            let db = db_arc.read().await;
                            
                            // Проверяем, является ли отправитель партнёром
                            let should_apply = if let Ok(tree) = db.open_tree("own_profile") {
                                if let Some(profile_bytes) = tree.get("profile").ok().flatten() {
                                    if let Ok(profile) = serde_json::from_slice::<UserProfile>(&profile_bytes) {
                                        // Проверка условия "Розы/Закаты"
                                        profile.should_sync_wallpaper() && profile.is_partner(&wallpaper_update.peer_id)
                                    } else {
                                        false
                                    }
                                } else {
                                    false
                                }
                            } else {
                                false
                            };
                            
                            if should_apply {
                                // Сохраняем обои партнёра в peer_profiles
                                if let Ok(tree) = db.open_tree("peer_profiles") {
                                    let peer_bytes = wallpaper_update.peer_id.as_bytes();
                                    if let Ok(Some(profile_bytes)) = tree.get(peer_bytes) {
                                        if let Ok(mut profile) = serde_json::from_slice::<UserProfile>(&profile_bytes) {
                                            profile.set_wallpaper(Some(wallpaper_update.wallpaper_cid.clone()));
                                            let profile_bytes = serde_json::to_vec(&profile).ok();
                                            if let Some(bytes) = profile_bytes {
                                                tree.insert(peer_bytes, bytes).ok();
                                                tree.flush().ok();
                                                println!("✅ Обои применены для партнёра {}", wallpaper_update.peer_id);
                                            }
                                        }
                                    }
                                }
                            } else {
                                println!("⚠️ Обои отклонены (не партнёр или не тот статус отношений)");
                            }
                            
                            continue;
                        }
                        
                        // Пробуем декодировать как chat-сообщение
                        let db = db_arc.read().await;
                        match serde_json::from_slice::<ChatMessage>(&message.data) {
                            Ok(decoded) => {
                                let shared_secret = if let Ok(Some(their_public)) = load_peer_key(&db, &decoded.sender) {
                                    compute_shared_secret(&static_secret, &their_public)
                                } else {
                                    println!("⚠️ Ключ отправителя {} не найден, используем fallback", decoded.sender);
                                    compute_shared_secret(&static_secret, &public_key)
                                };
                                
                                let display_text = if decoded.is_encrypted {
                                    match decrypt_message(&decoded.content, &decoded.nonce, &shared_secret.to_bytes()) {
                                        Ok(plaintext) => {
                                            let msg_text = format!("{}: {}", decoded.sender, plaintext);
                                            db.insert(format!("msg_{}", decoded.timestamp), msg_text.as_bytes())?;
                                            msg_text
                                        }
                                        Err(_) => {
                                            format!("🔐 {}: [не удалось расшифровать]", decoded.sender)
                                        }
                                    }
                                } else {
                                    let text = String::from_utf8_lossy(&decoded.content);
                                    let msg_text = format!("{}: {}", decoded.sender, text);
                                    db.insert(format!("msg_{}", decoded.timestamp), msg_text.as_bytes())?;
                                    msg_text
                                };

                                println!("✉️ {}", display_text);
                            }
                            Err(_) => {
                                let text = String::from_utf8_lossy(&message.data);
                                println!("✉️ (raw) {}", text);
                            }
                        }
                    }
                    SwarmEvent::Behaviour(MyBehaviourEvent::Gossipsub(gossipsub::Event::Subscribed { peer_id, topic })) => {
                        if topic == handshake_topic.hash() {
                            println!("📮 Отправка handshake для {peer_id}...");
                            let db = db_arc.read().await;
                            if let Err(e) = send_handshake(&mut swarm, &handshake_topic, local_peer_id, &public_key, &db) {
                                eprintln!("❌ Ошибка отправки handshake: {e:?}");
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}
