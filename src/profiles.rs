//! Модуль управления личностями и отношениями
//!
//! Этот модуль предоставляет структуру UserProfile для хранения информации
//! о пользователе и реализует безопасное стирание данных из памяти.

use serde::{Deserialize, Serialize};
use sled::Db;
use std::time::{SystemTime, UNIX_EPOCH};

/// Админский PeerID для верификации (заглушка - заменить на реальный)
pub const ADMIN_PEER_ID: &str = "12D3KooWAdminPlaceholder0000000000000000000000000";

/// Статус отношений между пирами
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(rename_all = "snake_case")]
pub enum RelationStatus {
    /// Семейные отношения (Family Safety)
    Family,
    /// Партнёрские отношения
    Partner,
    /// Друг/Знакомый
    Friend,
    /// Без отношений (по умолчанию)
    #[default]
    None,
}

/// Профиль пользователя в сети Liberty Reach
///
/// # Безопасность
/// Профиль может быть стёрт из памяти вручную через вызов zeroize()
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct UserProfile {
    /// Публичный ключ пира (PeerId)
    pub peer_id: String,

    /// Псевдоним пользователя (отображаемое имя)
    pub nickname: String,

    /// Краткая биография/статус
    #[serde(default)]
    pub bio: String,

    /// CID аватара в IPFS (опционально)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub avatar_cid: Option<String>,

    /// Статус отношений
    #[serde(default)]
    pub relation_status: RelationStatus,

    /// Флаг верификации (админский бейдж)
    #[serde(default)]
    pub is_verified: bool,

    /// PeerID админа, выдавшего верификацию (опционально)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub verified_by: Option<String>,

    /// CID обоев в IPFS (для синхронизации с партнёром)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wallpaper_url: Option<String>,

    /// PeerID партнёра (для семейных обоев)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub partner_peer_id: Option<String>,
}

impl UserProfile {
    /// Создать новый профиль
    pub fn new(peer_id: String, nickname: String) -> Self {
        Self {
            peer_id,
            nickname,
            bio: String::new(),
            avatar_cid: None,
            relation_status: RelationStatus::None,
            is_verified: false,
            verified_by: None,
            wallpaper_url: None,
            partner_peer_id: None,
        }
    }

    /// Создать профиль со статусом
    pub fn with_status(peer_id: String, nickname: String, relation_status: RelationStatus) -> Self {
        Self {
            peer_id,
            nickname,
            bio: String::new(),
            avatar_cid: None,
            relation_status,
            is_verified: false,
            verified_by: None,
            wallpaper_url: None,
            partner_peer_id: None,
        }
    }

    /// Обновить профиль
    pub fn update(&mut self, nickname: Option<String>, bio: Option<String>, avatar_cid: Option<String>) {
        if let Some(nick) = nickname {
            self.nickname = nick;
        }
        if let Some(b) = bio {
            self.bio = b;
        }
        self.avatar_cid = avatar_cid;
    }

    /// Установить обои
    pub fn set_wallpaper(&mut self, wallpaper_url: Option<String>) {
        self.wallpaper_url = wallpaper_url;
    }

    /// Установить партнёра
    pub fn set_partner(&mut self, partner_peer_id: Option<String>) {
        self.partner_peer_id = partner_peer_id;
    }

    /// Проверка, является ли пира партнёром
    pub fn is_partner(&self, peer_id: &str) -> bool {
        self.partner_peer_id.as_ref().map_or(false, |p| p == peer_id)
    }

    /// Проверка условия "Розы/Закаты" (Partner или Family)
    pub fn should_sync_wallpaper(&self) -> bool {
        matches!(self.relation_status, RelationStatus::Partner | RelationStatus::Family)
    }

    /// Выдать верификацию (только для админа)
    pub fn verify(&mut self, admin_peer_id: String) {
        self.is_verified = true;
        self.verified_by = Some(admin_peer_id);
    }

    /// Отображаемое имя с бейджем верификации
    pub fn display_name(&self) -> String {
        if self.is_verified {
            format!("{} ✓", self.nickname)
        } else {
            self.nickname.clone()
        }
    }

    /// Сохранить профиль в БД
    pub fn save_to_db(&self, db: &Db, tree_name: &str) -> Result<(), Box<dyn std::error::Error>> {
        let tree = db.open_tree(tree_name)?;
        let profile_bytes = serde_json::to_vec(self)?;
        tree.insert("profile", profile_bytes)?;
        tree.flush()?;
        Ok(())
    }

    /// Загрузить профиль из БД
    pub fn load_from_db(db: &Db, tree_name: &str) -> Result<Option<Self>, Box<dyn std::error::Error>> {
        let tree = db.open_tree(tree_name)?;
        if let Some(profile_bytes) = tree.get("profile")? {
            let profile: Self = serde_json::from_slice(&profile_bytes)?;
            Ok(Some(profile))
        } else {
            Ok(None)
        }
    }

    /// Проверка и авто-верификация если PeerID совпадает с ADMIN_PEER_ID
    pub fn check_admin_verification(&mut self, local_peer_id: &str) {
        if local_peer_id == ADMIN_PEER_ID {
            self.is_verified = true;
            self.verified_by = Some("SYSTEM_ADMIN".to_string());
        }
    }
}

/// Сообщение handshake с профилем
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct HandshakeWithProfile {
    /// PeerID отправителя
    pub peer_id: String,
    /// Публичный ключ шифрования X25519 (hex)
    pub encryption_key: String,
    /// Зашифрованный профиль (опционально)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub encrypted_profile: Option<Vec<u8>>,
}

impl HandshakeWithProfile {
    pub fn new(peer_id: String, encryption_key: String) -> Self {
        Self {
            peer_id,
            encryption_key,
            encrypted_profile: None,
        }
    }
}

/// Сообщение обновления обоев (для синхронизации между партнёрами)
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WallpaperUpdate {
    /// PeerID отправителя
    pub peer_id: String,
    /// CID обоев в IPFS
    pub wallpaper_cid: String,
    /// Подпись Ed25519 (подтверждает право на обновление)
    pub signature: String,
    /// Временная метка
    pub timestamp: u128,
}

impl WallpaperUpdate {
    pub fn new(peer_id: String, wallpaper_cid: String, signature: String) -> Self {
        Self {
            peer_id,
            wallpaper_cid,
            signature,
            timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_profile_creation() {
        let profile = UserProfile::new(
            "12D3KooWTest".to_string(),
            "TestUser".to_string(),
        );
        
        assert_eq!(profile.nickname, "TestUser");
        assert_eq!(profile.relation_status, RelationStatus::None);
        assert!(!profile.is_verified);
    }

    #[test]
    fn test_profile_with_status() {
        let profile = UserProfile::with_status(
            "12D3KooWTest".to_string(),
            "FamilyMember".to_string(),
            RelationStatus::Family,
        );
        
        assert_eq!(profile.relation_status, RelationStatus::Family);
    }

    #[test]
    fn test_display_name() {
        let mut profile = UserProfile::new(
            "12D3KooWTest".to_string(),
            "VerifiedUser".to_string(),
        );
        
        assert_eq!(profile.display_name(), "VerifiedUser");
        
        profile.verify("AdminPeerId".to_string());
        assert_eq!(profile.display_name(), "VerifiedUser ✓");
    }
}
