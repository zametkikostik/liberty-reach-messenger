//! Admin Handlers & Middleware for Liberty Sovereign
//!
//! Защищённый роутер для административных функций:
//! - /api/v1/admin/* - требует проверки ADMIN_PEER_ID
//! - Конфигурация OpenRouter
//! - Бан/разбан PeerID
//! - Доступ к Sled DB

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::{delete, get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use sled::Db;
use std::sync::Arc;

/// AppState для админ-панели
#[derive(Clone)]
pub struct AdminState {
    pub db: Arc<Db>,
    pub admin_peer_id: String,
}

/// Middleware для проверки админских прав
pub async fn admin_auth(
    State(state): State<AdminState>,
    headers: axum::http::HeaderMap,
) -> Result<(), StatusCode> {
    // Получаем PeerID из заголовка X-Peer-ID
    let peer_id = headers
        .get("X-Peer-ID")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Проверяем совпадение с ADMIN_PEER_ID
    if peer_id != state.admin_peer_id {
        return Err(StatusCode::FORBIDDEN);
    }

    Ok(())
}

/// Admin Config для OpenRouter и модерации
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdminConfig {
    pub openrouter_model: String,
    pub openrouter_api_key: Option<String>,
    pub toxicity_threshold: f32,
    pub ai_rate_limit: u32,
    pub auto_mute_threshold: u32,
}

impl Default for AdminConfig {
    fn default() -> Self {
        Self {
            openrouter_model: "google/gemma-2-9b-it:free".to_string(),
            openrouter_api_key: None,
            toxicity_threshold: 0.7,
            ai_rate_limit: 10,
            auto_mute_threshold: 3,
        }
    }
}

impl AdminConfig {
    pub fn load(db: &Db) -> Result<Self, Box<dyn std::error::Error>> {
        if let Some(bytes) = db.get("admin_config")? {
            Ok(serde_json::from_slice(&bytes)?)
        } else {
            let config = Self::default();
            db.insert("admin_config", serde_json::to_vec(&config)?)?;
            Ok(config)
        }
    }

    pub fn save(&self, db: &Db) -> Result<(), Box<dyn std::error::Error>> {
        db.insert("admin_config", serde_json::to_vec(self)?)?;
        db.flush()?;
        Ok(())
    }
}

/// Запрос на обновление конфига
#[derive(Debug, Deserialize)]
pub struct UpdateConfigRequest {
    pub openrouter_model: Option<String>,
    pub openrouter_api_key: Option<String>,
    pub toxicity_threshold: Option<f32>,
    pub ai_rate_limit: Option<u32>,
    pub auto_mute_threshold: Option<u32>,
}

/// Response с конфигом
#[derive(Debug, Serialize)]
pub struct ConfigResponse {
    pub openrouter_model: String,
    pub openrouter_api_key_set: bool,
    pub toxicity_threshold: f32,
    pub ai_rate_limit: u32,
    pub auto_mute_threshold: u32,
}

/// Запрос на бан PeerID
#[derive(Debug, Deserialize)]
pub struct BanRequest {
    pub peer_id: String,
    pub reason: String,
    pub duration_hours: Option<u64>,
}

/// Информация о забаненном PeerID
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BannedPeer {
    pub peer_id: String,
    pub reason: String,
    pub banned_at: u128,
    pub expires_at: Option<u128>,
    pub banned_by: String,
}

/// Response со списком забаненных
#[derive(Debug, Serialize)]
pub struct BanListResponse {
    pub banned_peers: Vec<BannedPeer>,
}

/// Response для zeroize операции
#[derive(Debug, Serialize)]
pub struct ZeroizeResponse {
    pub status: String,
    pub cleared_trees: Vec<String>,
    pub timestamp: u128,
}

/// Response для geo location
#[derive(Debug, Serialize)]
pub struct GeoLocationResponse {
    pub peer_id: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub cell_id: Option<String>,
    pub lac: Option<u16>,
    pub timestamp: i64,
    pub source: String,
}

/// Response для SOS signals
#[derive(Debug, Serialize)]
pub struct SosSignalResponse {
    pub user_peer_id: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub message: Option<String>,
    pub timestamp: i64,
    pub status: String,
}

/// Создать роутер для админ-панели
pub fn admin_router(state: AdminState) -> Router {
    Router::new()
        // Config endpoints
        .route("/config", get(get_config))
        .route("/config", post(update_config))
        // Ban management
        .route("/bans", get(get_ban_list))
        .route("/bans", post(ban_peer))
        .route("/bans/:peer_id", delete(unban_peer))
        // DB access
        .route("/db/stats", get(get_db_stats))
        .route("/db/keys", get(get_db_keys))
        // GDPR Zeroize
        .route("/zeroize", post(zeroize_all_metadata))
        // Geo Location endpoints
        .route("/geo/location/:peer_id", get(get_geo_location))
        .route("/geo/sos/active", get(get_active_sos_signals))
        .route("/geo/sos/resolve", post(resolve_sos_signal))
        .route("/geo/trusted/:peer_id", get(get_trusted_contacts))
        .route("/geo/emergency/request", post(emergency_request))
        // Reports
        .route("/reports", get(get_reports))
        .route("/reports/:report_id/review", post(review_report))
        // Middleware для проверки админских прав
        .layer(axum::middleware::from_fn_with_state(
            state.clone(),
            admin_auth_middleware,
        ))
        .with_state(state)
}

/// Middleware для проверки админских прав
async fn admin_auth_middleware(
    State(state): State<AdminState>,
    mut request: axum::http::Request<axum::body::Body>,
    next: axum::middleware::Next,
) -> Result<axum::response::Response, StatusCode> {
    let headers = request.headers();
    
    // Получаем PeerID из заголовка X-Peer-ID
    let peer_id = headers
        .get("X-Peer-ID")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Проверяем совпадение с ADMIN_PEER_ID
    if peer_id != state.admin_peer_id {
        return Err(StatusCode::FORBIDDEN);
    }

    Ok(next.run(request).await)
}

/// GET /api/v1/admin/config
async fn get_config(
    State(state): State<AdminState>,
) -> Result<Json<ConfigResponse>, StatusCode> {
    let config = AdminConfig::load(&state.db)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(ConfigResponse {
        openrouter_model: config.openrouter_model,
        openrouter_api_key_set: config.openrouter_api_key.is_some(),
        toxicity_threshold: config.toxicity_threshold,
        ai_rate_limit: config.ai_rate_limit,
        auto_mute_threshold: config.auto_mute_threshold,
    }))
}

/// POST /api/v1/admin/config
async fn update_config(
    State(state): State<AdminState>,
    Json(req): Json<UpdateConfigRequest>,
) -> Result<Json<ConfigResponse>, StatusCode> {
    let mut config = AdminConfig::load(&state.db)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if let Some(model) = req.openrouter_model {
        config.openrouter_model = model;
    }
    if let Some(key) = req.openrouter_api_key {
        config.openrouter_api_key = Some(key);
    }
    if let Some(threshold) = req.toxicity_threshold {
        config.toxicity_threshold = threshold;
    }
    if let Some(limit) = req.ai_rate_limit {
        config.ai_rate_limit = limit;
    }
    if let Some(mute_threshold) = req.auto_mute_threshold {
        config.auto_mute_threshold = mute_threshold;
    }

    config
        .save(&state.db)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(ConfigResponse {
        openrouter_model: config.openrouter_model,
        openrouter_api_key_set: config.openrouter_api_key.is_some(),
        toxicity_threshold: config.toxicity_threshold,
        ai_rate_limit: config.ai_rate_limit,
        auto_mute_threshold: config.auto_mute_threshold,
    }))
}

/// GET /api/v1/admin/bans
async fn get_ban_list(
    State(state): State<AdminState>,
) -> Result<Json<BanListResponse>, StatusCode> {
    let tree = state
        .db
        .open_tree("banned_peers")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut banned_peers = Vec::new();
    for entry in tree.iter() {
        if let Ok((_, value)) = entry {
            if let Ok(peer) = serde_json::from_slice::<BannedPeer>(&value) {
                banned_peers.push(peer);
            }
        }
    }

    Ok(Json(BanListResponse { banned_peers }))
}

/// POST /api/v1/admin/bans
async fn ban_peer(
    State(state): State<AdminState>,
    Json(req): Json<BanRequest>,
) -> Result<StatusCode, StatusCode> {
    let tree = state
        .db
        .open_tree("banned_peers")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis();

    let expires_at = req.duration_hours.map(|h| now + (h as u128) * 3600_000);

    let banned_peer = BannedPeer {
        peer_id: req.peer_id.clone(),
        reason: req.reason.clone(),
        banned_at: now,
        expires_at,
        banned_by: state.admin_peer_id.clone(),
    };

    tree.insert(
        req.peer_id.as_bytes(),
        serde_json::to_vec(&banned_peer).unwrap(),
    )
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// DELETE /api/v1/admin/bans/:peer_id
async fn unban_peer(
    State(state): State<AdminState>,
    Path(peer_id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let tree = state
        .db
        .open_tree("banned_peers")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    tree.remove(peer_id.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// GET /api/v1/admin/db/stats
async fn get_db_stats(
    State(state): State<AdminState>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut stats = serde_json::Map::new();

    // Получаем количество ключей в каждом tree
    let trees = [
        "peer_identities",
        "stories",
        "admin_reports",
        "banned_peers",
        "media_metadata",
        "admin_config",
    ];

    for tree_name in &trees {
        if let Ok(tree) = state.db.open_tree(tree_name) {
            stats.insert(tree_name.to_string(), serde_json::json!(tree.len()));
        }
    }

    // Общая статистика
    stats.insert(
        "size_on_disk".to_string(),
        serde_json::json!(state.db.size_on_disk().unwrap_or(0)),
    );

    Ok(Json(serde_json::Value::Object(stats)))
}

/// GET /api/v1/admin/db/keys
async fn get_db_keys(
    State(state): State<AdminState>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let mut keys = Vec::new();

    // Получаем все ключи из основного дерева
    for entry in state.db.iter() {
        if let Ok((key, _)) = entry {
            if let Ok(key_str) = String::from_utf8(key.to_vec()) {
                keys.push(key_str);
            }
        }
    }

    Ok(Json(keys))
}

/// GET /api/v1/admin/reports
async fn get_reports(
    State(state): State<AdminState>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let tree = state
        .db
        .open_tree("admin_reports")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut reports = Vec::new();
    for entry in tree.iter() {
        if let Ok((_, value)) = entry {
            if let Ok(report) = serde_json::from_slice::<serde_json::Value>(&value) {
                reports.push(report);
            }
        }
    }

    Ok(Json(reports))
}

/// POST /api/v1/admin/reports/:report_id/review
async fn review_report(
    State(state): State<AdminState>,
    Path(report_id): Path<String>,
    Json(req): Json<serde_json::Value>,
) -> Result<StatusCode, StatusCode> {
    let tree = state
        .db
        .open_tree("admin_reports")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if let Some(mut report) = tree
        .get(report_id.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
    {
        if let Ok(mut report_json) = serde_json::from_slice::<serde_json::Value>(&report) {
            // Обновляем статус рассмотрения
            if let Some(obj) = report_json.as_object_mut() {
                obj.insert("reviewed".to_string(), serde_json::json!(true));
                obj.insert(
                    "reviewed_at".to_string(),
                    serde_json::json!(
                        std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap()
                            .as_millis()
                    ),
                );
                obj.insert(
                    "reviewed_by".to_string(),
                    serde_json::json!(state.admin_peer_id),
                );

                // Добавляем заметки если есть
                if let Some(notes) = req.get("notes") {
                    obj.insert("notes".to_string(), notes.clone());
                }
            }

            let report_bytes = serde_json::to_vec(&report_json).unwrap();
            tree.insert(report_id.as_bytes(), report_bytes)
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

            return Ok(StatusCode::OK);
        }
    }

    Err(StatusCode::NOT_FOUND)
}

/// POST /api/v1/admin/zeroize
/// GDPR: Мгновенная очистка всех локальных метаданных и ключей шифрования
async fn zeroize_all_metadata(
    State(state): State<AdminState>,
) -> Result<Json<ZeroizeResponse>, StatusCode> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis();

    let mut cleared_trees = Vec::new();

    // Список деревьев для очистки
    let trees_to_clear = [
        "peer_identities",
        "encryption_keys",
        "chat_history",
        "media_metadata",
        "geo_locations",
        "sos_signals",
        "trusted_contacts",
        "emergency_logs",
        "admin_reports",
        "banned_peers",
        "stories",
        "group_members",
        "invitation_tokens",
    ];

    for tree_name in &trees_to_clear {
        if let Ok(tree) = state.db.open_tree(tree_name) {
            let count = tree.len();
            tree.clear().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            
            if count > 0 {
                cleared_trees.push(format!("{} ({} entries)", tree_name, count));
            }
        }
    }

    // Очистка основного дерева
    if let Ok(main_tree) = state.db.open_tree("default") {
        main_tree.clear().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        main_tree.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        cleared_trees.push("default".to_string());
    }

    // Принудительная синхронизация
    state.db.flush().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    println!("🗑️ GDPR Zeroize: Удалено {} деревьев", cleared_trees.len());

    Ok(Json(ZeroizeResponse {
        status: "All data zeroized successfully".to_string(),
        cleared_trees,
        timestamp: now,
    }))
}

/// GET /api/v1/admin/geo/location/:peer_id
/// Получить последнее местоположение пользователя
async fn get_geo_location(
    State(state): State<AdminState>,
    Path(peer_id): Path<String>,
) -> Result<Json<GeoLocationResponse>, StatusCode> {
    use crate::geo::GeoManager;
    
    let geo_manager = GeoManager::new(state.db.clone());
    let location = geo_manager.get_last_location(&peer_id).await
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(GeoLocationResponse {
        peer_id,
        latitude: location.latitude,
        longitude: location.longitude,
        cell_id: location.cell_id,
        lac: location.lac,
        timestamp: location.timestamp.timestamp(),
        source: format!("{:?}", location.source),
    }))
}

/// GET /api/v1/admin/geo/sos/active
/// Получить активные SOS сигналы
async fn get_active_sos_signals(
    State(state): State<AdminState>,
) -> Result<Json<Vec<SosSignalResponse>>, StatusCode> {
    use crate::geo::GeoManager;
    
    let geo_manager = GeoManager::new(state.db.clone());
    let sos_signals = geo_manager.get_active_sos().await;

    let responses: Vec<SosSignalResponse> = sos_signals.iter().map(|s| {
        SosSignalResponse {
            user_peer_id: s.user_peer_id.clone(),
            latitude: s.location.latitude,
            longitude: s.location.longitude,
            message: s.message.clone(),
            timestamp: s.timestamp.timestamp(),
            status: format!("{:?}", s.status),
        }
    }).collect();

    Ok(Json(responses))
}

/// POST /api/v1/admin/geo/sos/resolve
/// Завершить SOS сигнал
async fn resolve_sos_signal(
    State(state): State<AdminState>,
    Json(req): Json<serde_json::Value>,
) -> Result<StatusCode, StatusCode> {
    use crate::geo::GeoManager;
    
    let peer_id = req["peer_id"].as_str().ok_or(StatusCode::BAD_REQUEST)?;
    let geo_manager = GeoManager::new(state.db.clone());
    
    geo_manager.resolve_sos(peer_id).await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// GET /api/v1/admin/geo/trusted/:peer_id
/// Получить доверенные контакты пользователя
async fn get_trusted_contacts(
    State(state): State<AdminState>,
    Path(peer_id): Path<String>,
) -> Result<Json<Vec<String>>, StatusCode> {
    use crate::geo::GeoManager;
    
    let geo_manager = GeoManager::new(state.db.clone());
    // TODO: Реализовать метод get_trusted_contacts в GeoManager
    // Пока возвращаем пустой список
    Ok(Json(vec![]))
}

/// POST /api/v1/admin/geo/emergency/request
/// Обработать emergency запрос
async fn emergency_request(
    State(state): State<AdminState>,
    Json(req): Json<serde_json::Value>,
) -> Result<Json<GeoLocationResponse>, StatusCode> {
    use crate::geo::GeoManager;
    
    let requester = req["requester_peer_id"].as_str().ok_or(StatusCode::BAD_REQUEST)?;
    let target = req["target_peer_id"].as_str().ok_or(StatusCode::BAD_REQUEST)?;
    let reason = req["reason"].as_str().unwrap_or("Emergency");
    
    let geo_manager = GeoManager::new(state.db.clone());
    
    // TODO: Реализовать полноценную обработку emergency запроса
    let location = geo_manager.get_last_location(target).await
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(GeoLocationResponse {
        peer_id: target.to_string(),
        latitude: location.latitude,
        longitude: location.longitude,
        cell_id: location.cell_id,
        lac: location.lac,
        timestamp: location.timestamp.timestamp(),
        source: format!("{:?}", location.source),
    }))
}
