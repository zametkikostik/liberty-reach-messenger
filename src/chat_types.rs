//! Advanced Chat Types & E2EE for Liberty Reach

use serde::{Deserialize, Serialize};

/// Типы чатов
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ChatType {
    OneToOne,
    PublicGroup,
    PrivateGroup,
    PublicChannel,
    PrivateChannel,
    SecretChat,
}

impl ChatType {
    pub fn to_topic(&self, chat_id: &str) -> String {
        match self {
            ChatType::OneToOne => format!("liberty-chat-1on1-{}", chat_id),
            ChatType::PublicGroup => format!("liberty-group-public-{}", chat_id),
            ChatType::PrivateGroup => format!("liberty-group-private-{}", chat_id),
            ChatType::PublicChannel => format!("liberty-channel-public-{}", chat_id),
            ChatType::PrivateChannel => format!("liberty-channel-private-{}", chat_id),
            ChatType::SecretChat => format!("liberty-secret-{}", chat_id),
        }
    }
    
    pub fn requires_e2ee(&self) -> bool {
        matches!(self, ChatType::OneToOne | ChatType::PrivateGroup | ChatType::SecretChat)
    }
}

/// AES-GCM E2EE шифрование
pub mod aes_e2ee {
    use aes_gcm::{aead::{Aead, KeyInit}, Aes256Gcm, Nonce};
    use rand::{rngs::OsRng, RngCore};
    use zeroize::Zeroizing;

    pub fn encrypt(plaintext: &[u8], key: &[u8; 32]) -> Result<(Vec<u8>, Vec<u8>), Box<dyn std::error::Error + Send + Sync>> {
        let cipher = Aes256Gcm::new_from_slice(key)?;
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let ciphertext = cipher.encrypt(&Nonce::from_slice(&nonce_bytes), plaintext)
            .map_err(|e| format!("Encryption error: {}", e))?;
        Ok((ciphertext, nonce_bytes.to_vec()))
    }

    pub fn decrypt(ciphertext: &[u8], nonce: &[u8], key: &[u8; 32]) -> Result<Zeroizing<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>> {
        let cipher = Aes256Gcm::new_from_slice(key)?;
        let plaintext = cipher.decrypt(&Nonce::from_slice(nonce), ciphertext)
            .map_err(|e| format!("Decryption error: {}", e))?;
        Ok(Zeroizing::new(plaintext))
    }
}

/// Геолокация для SOS
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeolocationData {
    pub latitude: f64,
    pub longitude: f64,
    pub accuracy: f32,
    pub cell_id: Option<String>,
    pub lac: Option<u16>,
    pub timestamp: u128,
}

impl GeolocationData {
    pub fn new(lat: f64, lon: f64, accuracy: f32) -> Self {
        Self {
            latitude: lat,
            longitude: lon,
            accuracy,
            cell_id: None,
            lac: None,
            timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis(),
        }
    }
    pub fn with_cell_tower(mut self, cell_id: String, lac: u16) -> Self {
        self.cell_id = Some(cell_id);
        self.lac = Some(lac);
        self
    }
}

/// SOS сигнал
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SosSignal {
    pub user_peer_id: String,
    pub location: GeolocationData,
    pub message: Option<String>,
    pub timestamp: u128,
    pub encrypted_for: Vec<String>,
}

impl SosSignal {
    pub fn new(user_peer_id: String, location: GeolocationData) -> Self {
        Self {
            user_peer_id,
            location,
            message: None,
            timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis(),
            encrypted_for: Vec::new(),
        }
    }
}

/// Статус пользователя (Identity & Premium)
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default, PartialEq, Eq)]
pub enum UserStatus {
    #[default]
    Unverified,
    Verified,
    Premium,
}

impl UserStatus {
    /// Premium пользователи получают bypass локальных word-фильтров
    pub fn bypass_local_filters(&self) -> bool {
        matches!(self, UserStatus::Premium)
    }

    /// Проверка, активен ли статус
    pub fn is_active(&self) -> bool {
        !matches!(self, UserStatus::Unverified)
    }
}

/// Premium статус
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PremiumStatus {
    pub is_premium: bool,
    pub verified_at: Option<u128>,
    pub transaction_hash: Option<String>,
    pub expires_at: Option<u128>,
}

impl PremiumStatus {
    pub fn new(tx_hash: String) -> Self {
        Self {
            is_premium: true,
            verified_at: Some(std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            transaction_hash: Some(tx_hash),
            expires_at: None,
        }
    }

    pub fn with_expiry(mut self, expires_at: u128) -> Self {
        self.expires_at = Some(expires_at);
        self
    }

    pub fn is_expired(&self) -> bool {
        if let Some(expires) = self.expires_at {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis();
            now > expires
        } else {
            false
        }
    }
}

/// Расширенный профиль
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ExtendedUserProfile {
    pub peer_id: String,
    pub nickname: String,
    pub is_verified: bool,
    pub verified_by: Option<String>,
    pub premium: PremiumStatus,
    pub wallet_address: Option<String>,
    pub user_status: UserStatus,
}

impl ExtendedUserProfile {
    /// Проверка прав доступа
    pub fn has_premium_bypass(&self) -> bool {
        self.user_status.bypass_local_filters() && !self.premium.is_expired()
    }
}

/// Репорт
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SuspiciousActivityReport {
    pub reported_peer: String,
    pub reporter_peer: String,
    pub reason: String,
    pub toxicity_score: f32,
    pub timestamp: u128,
    pub message_hash: String,
    pub reviewed: bool,
}

impl SuspiciousActivityReport {
    pub fn new(reported: String, reporter: String, reason: String, score: f32, hash: String) -> Self {
        Self {
            reported_peer: reported,
            reporter_peer: reporter,
            reason,
            toxicity_score: score,
            timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis(),
            message_hash: hash,
            reviewed: false,
        }
    }
}

/// Админ конфиг
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdminConfig {
    pub openrouter_model: String,
    pub toxicity_threshold: f32,
    pub ai_rate_limit: u32,
    pub auto_mute_threshold: u32,
}

impl Default for AdminConfig {
    fn default() -> Self {
        Self {
            openrouter_model: "google/gemma-2-9b-it:free".to_string(),
            toxicity_threshold: 0.7,
            ai_rate_limit: 10,
            auto_mute_threshold: 3,
        }
    }
}

impl AdminConfig {
    pub fn load(db: &sled::Db) -> Result<Self, Box<dyn std::error::Error>> {
        if let Some(bytes) = db.get("admin_config")? {
            Ok(serde_json::from_slice(&bytes)?)
        } else {
            let config = Self::default();
            db.insert("admin_config", serde_json::to_vec(&config)?)?;
            Ok(config)
        }
    }
    
    pub fn save(&self, db: &sled::Db) -> Result<(), Box<dyn std::error::Error>> {
        db.insert("admin_config", serde_json::to_vec(self)?)?;
        Ok(())
    }
    
    pub fn update_model(&mut self, model: String) {
        self.openrouter_model = model;
    }
    
    pub fn update_threshold(&mut self, threshold: f32) {
        self.toxicity_threshold = threshold;
    }
}

/// Report Queue
pub struct ReportQueue {
    db: sled::Db,
}

impl ReportQueue {
    pub fn new(db: sled::Db) -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self { db })
    }
    
    pub fn add_report(&self, report: &SuspiciousActivityReport) -> Result<(), Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("admin_reports")?;
        let key = format!("report_{}_{}", report.reported_peer, report.timestamp);
        tree.insert(key.as_bytes(), serde_json::to_vec(report)?)?;
        tree.flush()?;
        Ok(())
    }
    
    pub fn get_pending_reports(&self) -> Result<Vec<SuspiciousActivityReport>, Box<dyn std::error::Error>> {
        let tree = self.db.open_tree("admin_reports")?;
        let mut reports = Vec::new();
        for entry in tree.iter() {
            if let Ok((_, value)) = entry {
                if let Ok(report) = serde_json::from_slice::<SuspiciousActivityReport>(&value) {
                    reports.push(report);
                }
            }
        }
        Ok(reports)
    }
}
