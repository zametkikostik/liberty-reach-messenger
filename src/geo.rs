//! Emergency Geolocation Module (The Guardian Engine)
//!
//! Функции:
//! - Интеграция карт (Maps placeholder)
//! - Поиск по вышкам (LBS - Location Based Service)
//! - Triangulation по cell tower data
//! - Emergency Request для родственников

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sled::Db;
use std::sync::Arc;

/// Данные геолокации (GPS + LBS)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoLocation {
    /// Широта (GPS)
    pub latitude: Option<f64>,
    /// Долгота (GPS)
    pub longitude: Option<f64>,
    /// Точность GPS в метрах
    pub gps_accuracy: Option<f32>,
    /// Cell ID (LBS)
    pub cell_id: Option<String>,
    /// Location Area Code (LAC)
    pub lac: Option<u16>,
    /// Mobile Country Code
    pub mcc: Option<u16>,
    /// Mobile Network Code
    pub mnc: Option<u16>,
    /// Время получения координат
    pub timestamp: DateTime<Utc>,
    /// Источник данных
    pub source: LocationSource,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum LocationSource {
    Gps,
    Lbs,
    Hybrid,
    Wifi,
}

impl GeoLocation {
    pub fn from_gps(latitude: f64, longitude: f64, accuracy: f32) -> Self {
        Self {
            latitude: Some(latitude),
            longitude: Some(longitude),
            gps_accuracy: Some(accuracy),
            cell_id: None,
            lac: None,
            mcc: None,
            mnc: None,
            timestamp: Utc::now(),
            source: LocationSource::Gps,
        }
    }

    pub fn from_lbs(cell_id: String, lac: u16, mcc: u16, mnc: u16) -> Self {
        Self {
            latitude: None,
            longitude: None,
            gps_accuracy: None,
            cell_id: Some(cell_id),
            lac: Some(lac),
            mcc: Some(mcc),
            mnc: Some(mnc),
            timestamp: Utc::now(),
            source: LocationSource::Lbs,
        }
    }

    pub fn hybrid(
        latitude: f64,
        longitude: f64,
        gps_accuracy: f32,
        cell_id: String,
        lac: u16,
    ) -> Self {
        Self {
            latitude: Some(latitude),
            longitude: Some(longitude),
            gps_accuracy: Some(gps_accuracy),
            cell_id: Some(cell_id),
            lac: Some(lac),
            mcc: None,
            mnc: None,
            timestamp: Utc::now(),
            source: LocationSource::Hybrid,
        }
    }

    /// Проверка, есть ли GPS координаты
    pub fn has_gps(&self) -> bool {
        self.latitude.is_some() && self.longitude.is_some()
    }

    /// Проверка, есть ли LBS данные
    pub fn has_lbs(&self) -> bool {
        self.cell_id.is_some() && self.lac.is_some()
    }

    /// Получить примерный радиус местоположения (метры)
    pub fn estimated_radius(&self) -> f64 {
        match self.source {
            LocationSource::Gps => self.gps_accuracy.unwrap_or(100.0) as f64,
            LocationSource::Lbs => 2000.0, // Вышки: ~2км радиус
            LocationSource::Hybrid => self.gps_accuracy.unwrap_or(500.0) as f64,
            LocationSource::Wifi => 100.0,
        }
    }
}

/// SOS сигнал бедствия
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SosSignal {
    /// PeerID пользователя
    pub user_peer_id: String,
    /// Местоположение
    pub location: GeoLocation,
    /// Сообщение (опционально)
    pub message: Option<String>,
    /// Временная метка
    pub timestamp: DateTime<Utc>,
    /// Зашифровано для кого (список PeerID)
    pub encrypted_for: Vec<String>,
    /// Статус (активен/обработан)
    pub status: SosStatus,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum SosStatus {
    Active,
    Acknowledged,
    Resolved,
    FalseAlarm,
}

impl SosSignal {
    pub fn new(user_peer_id: String, location: GeoLocation) -> Self {
        Self {
            user_peer_id,
            location,
            message: None,
            timestamp: Utc::now(),
            encrypted_for: Vec::new(),
            status: SosStatus::Active,
        }
    }

    pub fn with_message(mut self, message: String) -> Self {
        self.message = Some(message);
        self
    }

    pub fn encrypt_for(mut self, peer_id: String) -> Self {
        self.encrypted_for.push(peer_id);
        self
    }
}

/// Запрос на экстренное определение местоположения
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmergencyLocationRequest {
    /// PeerID запрашивающего (родственник)
    pub requester_peer_id: String,
    /// PeerID целевого пользователя
    pub target_peer_id: String,
    /// Причина запроса
    pub reason: String,
    /// Временная метка
    pub timestamp: DateTime<Utc>,
    /// Статус верификации
    pub verified: bool,
}

impl EmergencyLocationRequest {
    pub fn new(requester_peer_id: String, target_peer_id: String, reason: String) -> Self {
        Self {
            requester_peer_id,
            target_peer_id,
            reason,
            timestamp: Utc::now(),
            verified: false,
        }
    }
}

/// Менеджер геолокации
pub struct GeoManager {
    db: Arc<Db>,
    /// Последний известный location для каждого пользователя
    last_known_locations: Arc<tokio::sync::RwLock<HashMap<String, GeoLocation>>>,
    /// Активные SOS сигналы
    active_sos: Arc<tokio::sync::RwLock<HashMap<String, SosSignal>>>,
    /// Доверенные контакты для emergency requests
    trusted_contacts: Arc<tokio::sync::RwLock<HashMap<String, Vec<String>>>>,
}

use std::collections::HashMap;

impl GeoManager {
    pub fn new(db: Arc<Db>) -> Self {
        Self {
            db,
            last_known_locations: Arc::new(tokio::sync::RwLock::new(HashMap::new())),
            active_sos: Arc::new(tokio::sync::RwLock::new(HashMap::new())),
            trusted_contacts: Arc::new(tokio::sync::RwLock::new(HashMap::new())),
        }
    }

    /// Обновить последнее известное местоположение
    pub async fn update_location(
        &self,
        peer_id: &str,
        location: GeoLocation,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut locations = self.last_known_locations.write().await;
        locations.insert(peer_id.to_string(), location.clone());

        // Сохранение в БД
        let tree = self.db.open_tree("geo_locations")?;
        let key = format!("loc_{}", peer_id);
        let value = serde_json::to_vec(&location)?;
        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;

        Ok(())
    }

    /// Получить последнее известное местоположение
    pub async fn get_last_location(&self, peer_id: &str) -> Option<GeoLocation> {
        // Сначала в памяти
        {
            let locations = self.last_known_locations.read().await;
            if let Some(loc) = locations.get(peer_id) {
                return Some(loc.clone());
            }
        }

        // Затем в БД
        if let Ok(tree) = self.db.open_tree("geo_locations") {
            let key = format!("loc_{}", peer_id);
            if let Ok(Some(bytes)) = tree.get(key.as_bytes()) {
                if let Ok(loc) = serde_json::from_slice(&bytes) {
                    return Some(loc);
                }
            }
        }

        None
    }

    /// Активировать SOS сигнал
    pub async fn activate_sos(&self, signal: SosSignal) -> Result<(), Box<dyn std::error::Error>> {
        let mut sos = self.active_sos.write().await;
        sos.insert(signal.user_peer_id.clone(), signal.clone());

        // Сохранение в БД
        let tree = self.db.open_tree("sos_signals")?;
        let key = format!("sos_{}", signal.user_peer_id);
        let value = serde_json::to_vec(&signal)?;
        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;

        Ok(())
    }

    /// Деактивировать SOS сигнал
    pub async fn resolve_sos(&self, peer_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut sos = self.active_sos.write().await;
        if let Some(signal) = sos.get_mut(peer_id) {
            signal.status = SosStatus::Resolved;
        }

        let tree = self.db.open_tree("sos_signals")?;
        let key = format!("sos_{}", peer_id);
        tree.remove(key.as_bytes())?;
        tree.flush()?;

        Ok(())
    }

    /// Получить активные SOS сигналы
    pub async fn get_active_sos(&self) -> Vec<SosSignal> {
        let sos = self.active_sos.read().await;
        sos.values()
            .filter(|s| s.status == SosStatus::Active)
            .cloned()
            .collect()
    }

    /// Добавить доверенный контакт
    pub async fn add_trusted_contact(
        &self,
        user_peer_id: &str,
        trusted_peer_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut contacts = self.trusted_contacts.write().await;
        let contacts_list: &mut Vec<String> = contacts
            .entry(user_peer_id.to_string())
            .or_insert_with(Vec::new);
        contacts_list.push(trusted_peer_id.to_string());

        // Сохранение в БД
        let tree = self.db.open_tree("trusted_contacts")?;
        let key = format!("trusted_{}", user_peer_id);
        let contacts_clone: Vec<String> = contacts_list.clone();
        let value = serde_json::to_vec(&contacts_clone)?;
        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;

        Ok(())
    }

    /// Проверить, является ли контакт доверенным
    pub async fn is_trusted_contact(
        &self,
        user_peer_id: &str,
        requester_peer_id: &str,
    ) -> bool {
        let contacts = self.trusted_contacts.read().await;
        if let Some(list) = contacts.get(user_peer_id) {
            return list.contains(&requester_peer_id.to_string());
        }
        false
    }

    /// Обработать emergency request
    pub async fn handle_emergency_request(
        &self,
        request: &EmergencyLocationRequest,
    ) -> Result<Option<GeoLocation>, Box<dyn std::error::Error>> {
        // Проверка верификации
        if !request.verified {
            return Err("Request not verified".into());
        }

        // Проверка доверенного контакта
        let is_trusted = self
            .is_trusted_contact(&request.target_peer_id, &request.requester_peer_id)
            .await;

        if !is_trusted {
            return Err("Requester is not a trusted contact".into());
        }

        // Получение последнего известного местоположения
        let location = self.get_last_location(&request.target_peer_id).await;

        // Логирование запроса
        self.log_emergency_request(request)?;

        Ok(location)
    }

    /// Логирование emergency запросов
    fn log_emergency_request(
        &self,
        request: &EmergencyLocationRequest,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("emergency_logs")?;
        let key = format!(
            "emergency_{}_{}",
            request.target_peer_id,
            request.timestamp.timestamp()
        );
        let value = serde_json::to_vec(request)?;
        tree.insert(key.as_bytes(), value)?;
        tree.flush()?;
        Ok(())
    }

    /// Triangulation по вышкам (placeholder для API операторов)
    pub async fn triangulate_by_towers(
        &self,
        cell_towers: Vec<CellTowerData>,
    ) -> Option<GeoLocation> {
        if cell_towers.is_empty() {
            return None;
        }

        // TODO: Интеграция с API операторов для триангуляции
        // Пока возвращаем примерные координаты на основе Cell ID

        // Примерная логика:
        // 1. Получить координаты вышек из базы операторов
        // 2. Вычислить центроид по весам (RSSI)
        // 3. Вернуть примерные координаты

        // Placeholder: используем первую вышку
        cell_towers.first().map(|tower| GeoLocation::from_lbs(
            tower.cell_id.clone(),
            tower.lac,
            tower.mcc,
            tower.mnc,
        ))
    }

    /// Получить историю перемещений пользователя
    pub async fn get_location_history(
        &self,
        peer_id: &str,
        limit: usize,
    ) -> Result<Vec<GeoLocation>, Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("geo_locations")?;
        let mut history: Vec<GeoLocation> = Vec::new();

        let prefix = format!("loc_{}", peer_id);
        for entry in tree.iter() {
            if let Ok((key, value)) = entry {
                if let Ok(key_str) = String::from_utf8(key.to_vec()) {
                    if key_str.starts_with(&prefix) {
                        if let Ok(loc) = serde_json::from_slice(&value) {
                            history.push(loc);
                        }
                    }
                }
            }
        }

        // Сортировка по времени (новые первые)
        history.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
        history.truncate(limit);

        Ok(history)
    }
}

/// Данные вышки сотовой связи
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CellTowerData {
    pub cell_id: String,
    pub lac: u16,
    pub mcc: u16,
    pub mnc: u16,
    pub rssi: Option<i16>, // Сигнал (dBm)
}

/// API для интеграции с картами
pub struct MapsIntegration {
    // Placeholder для интеграции с Maps API
    // Google Maps, OpenStreetMap, etc.
}

impl MapsIntegration {
    pub fn new() -> Self {
        Self {}
    }

    /// Получить URL для отображения координат на карте
    pub fn get_map_url(&self, location: &GeoLocation) -> String {
        if let (Some(lat), Some(lon)) = (location.latitude, location.longitude) {
            format!("https://www.openstreetmap.org/?mlat={}&mlon={}", lat, lon)
        } else {
            String::new()
        }
    }

    /// Reverse geocoding (координаты -> адрес)
    pub async fn reverse_geocode(
        &self,
        latitude: f64,
        longitude: f64,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // TODO: Интеграция с Nominatim или другим сервисом
        Ok(format!("Coordinates: {}, {}", latitude, longitude))
    }
}

impl Default for MapsIntegration {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_update_location() {
        let dir = tempdir().unwrap();
        let db = sled::open(dir.path()).unwrap();
        let manager = GeoManager::new(Arc::new(db));

        let location = GeoLocation::from_gps(55.7558, 37.6173, 10.0);
        manager
            .update_location("user123", location.clone())
            .await
            .unwrap();

        let retrieved = manager.get_last_location("user123").await.unwrap();
        assert_eq!(retrieved.latitude, Some(55.7558));
        assert_eq!(retrieved.longitude, Some(37.6173));
    }

    #[test]
    fn test_location_radius() {
        let gps_loc = GeoLocation::from_gps(55.7558, 37.6173, 5.0);
        assert!(gps_loc.estimated_radius() < 100.0);

        let lbs_loc = GeoLocation::from_lbs("cell1".to_string(), 1234, 250, 1);
        assert_eq!(lbs_loc.estimated_radius(), 2000.0);
    }
}
