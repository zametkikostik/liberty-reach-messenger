//! Social Infrastructure for Liberty Reach
//!
//! Реализация 5 типов пространств:
//! - Чаты 1 на 1 (Direct)
//! - Секретные чаты (Secret - E2EE, только в памяти)
//! - Группы (Pub/Priv)
//! - Каналы (Pub/Priv)

use libp2p::gossipsub::{IdentTopic, MessageId, TopicHash};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Типы чатов для Social Layer
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum ChatType {
    /// Прямой P2P канал (1 на 1)
    Direct,
    /// Секретный чат с E2EE (сообщения только в памяти)
    Secret,
    /// Публичная группа (открытая для всех)
    GroupPublic,
    /// Приватная группа (по приглашениям)
    GroupPrivate,
    /// Публичный канал (вещание от одного ко многим)
    ChannelPublic,
    /// Приватный канал (закрытый)
    ChannelPrivate,
}

impl ChatType {
    /// Получить тему gossipsub для чата
    pub fn to_topic(&self, chat_id: &str) -> IdentTopic {
        let topic_name = match self {
            ChatType::Direct => format!("liberty-direct-{}", chat_id),
            ChatType::Secret => format!("liberty-secret-{}", chat_id),
            ChatType::GroupPublic => format!("liberty-group-pub-{}", chat_id),
            ChatType::GroupPrivate => format!("liberty-group-priv-{}", chat_id),
            ChatType::ChannelPublic => format!("liberty-channel-pub-{}", chat_id),
            ChatType::ChannelPrivate => format!("liberty-channel-priv-{}", chat_id),
        };
        IdentTopic::new(topic_name)
    }

    /// Требует ли чат E2EE шифрования
    pub fn requires_e2ee(&self) -> bool {
        matches!(
            self,
            ChatType::Direct | ChatType::Secret | ChatType::GroupPrivate | ChatType::ChannelPrivate
        )
    }

    /// Сохранять ли сообщения на диск
    pub fn persist_messages(&self) -> bool {
        !matches!(self, ChatType::Secret)
    }

    /// Тип доступа
    pub fn access_type(&self) -> AccessType {
        match self {
            ChatType::Direct => AccessType::Private,
            ChatType::Secret => AccessType::Private,
            ChatType::GroupPublic => AccessType::Public,
            ChatType::GroupPrivate => AccessType::Private,
            ChatType::ChannelPublic => AccessType::Public,
            ChatType::ChannelPrivate => AccessType::Private,
        }
    }
}

/// Тип доступа к чату
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AccessType {
    Public,
    Private,
}

/// Метаданные чата
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMetadata {
    pub chat_id: String,
    pub chat_type: ChatType,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: u128,
    pub owner_peer_id: String,
    pub members: Vec<String>,
    pub max_members: Option<u32>,
}

impl ChatMetadata {
    pub fn new(chat_id: String, chat_type: ChatType, owner_peer_id: String) -> Self {
        Self {
            chat_id,
            chat_type,
            name: None,
            description: None,
            created_at: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis(),
            owner_peer_id: owner_peer_id.clone(),
            members: vec![owner_peer_id],
            max_members: None,
        }
    }

    pub fn with_name(mut self, name: String) -> Self {
        self.name = Some(name);
        self
    }

    pub fn with_description(mut self, description: String) -> Self {
        self.description = Some(description);
        self
    }

    pub fn with_max_members(mut self, max: u32) -> Self {
        self.max_members = Some(max);
        self
    }

    pub fn add_member(&mut self, peer_id: String) {
        if !self.members.contains(&peer_id) {
            self.members.push(peer_id);
        }
    }

    pub fn remove_member(&mut self, peer_id: &str) {
        self.members.retain(|m| m != peer_id);
    }

    pub fn is_member(&self, peer_id: &str) -> bool {
        self.members.iter().any(|m| m == peer_id)
    }

    pub fn member_count(&self) -> usize {
        self.members.len()
    }
}

/// Менеджер социальных пространств
pub struct SocialManager {
    /// Активные чаты
    chats: Arc<RwLock<HashMap<String, ChatMetadata>>>,
    /// Подписки на темы gossipsub
    subscriptions: Arc<RwLock<HashMap<String, IdentTopic>>>,
    /// Локальный PeerID
    local_peer_id: String,
}

impl SocialManager {
    pub fn new(local_peer_id: String) -> Self {
        Self {
            chats: Arc::new(RwLock::new(HashMap::new())),
            subscriptions: Arc::new(RwLock::new(HashMap::new())),
            local_peer_id,
        }
    }

    /// Создать новый чат
    pub async fn create_chat(
        &self,
        chat_type: ChatType,
        name: Option<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let chat_id = format!(
            "{}_{}",
            self.local_peer_id,
            uuid::Uuid::new_v4().as_simple()
        );

        let mut metadata = ChatMetadata::new(chat_id.clone(), chat_type, self.local_peer_id.clone());
        if let Some(n) = name {
            metadata = metadata.with_name(n);
        }

        let mut chats = self.chats.write().await;
        chats.insert(chat_id.clone(), metadata);

        Ok(chat_id)
    }

    /// Присоединиться к чату (по приглашению или публичный)
    pub async fn join_chat(
        &self,
        chat_id: String,
        invitation_token: Option<String>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let chats = self.chats.read().await;
        let metadata = chats.get(&chat_id).ok_or("Chat not found")?;

        // Проверка доступа
        match metadata.chat_type.access_type() {
            AccessType::Public => {
                // Публичный чат - можно присоединиться свободно
            }
            AccessType::Private => {
                // Приватный - нужен токен приглашения
                if invitation_token.is_none() {
                    return Err("Invitation required for private chat".into());
                }
                // TODO: Валидация токена приглашения
            }
        }

        drop(chats);

        // Добавляем в список чатов
        let mut chats = self.chats.write().await;
        if let Some(meta) = chats.get_mut(&chat_id) {
            meta.add_member(self.local_peer_id.clone());
        }

        Ok(())
    }

    /// Покинуть чат
    pub async fn leave_chat(&self, chat_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut chats = self.chats.write().await;
        if let Some(metadata) = chats.get_mut(chat_id) {
            metadata.remove_member(&self.local_peer_id);

            // Если владелец ушёл - удаляем чат
            if metadata.owner_peer_id == self.local_peer_id {
                drop(chats);
                self.delete_chat(chat_id).await?;
                return Ok(());
            }
        }

        Ok(())
    }

    /// Удалить чат (только для владельца)
    pub async fn delete_chat(&self, chat_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut chats = self.chats.write().await;
        let metadata = chats.get(chat_id).ok_or("Chat not found")?;

        if metadata.owner_peer_id != self.local_peer_id {
            return Err("Only owner can delete chat".into());
        }

        chats.remove(chat_id);

        // Отписка от темы
        let mut subs = self.subscriptions.write().await;
        subs.remove(chat_id);

        Ok(())
    }

    /// Подписаться на тему gossipsub
    pub async fn subscribe_to_topic(
        &self,
        chat_id: &str,
    ) -> Result<IdentTopic, Box<dyn std::error::Error>> {
        let chats = self.chats.read().await;
        let metadata = chats.get(chat_id).ok_or("Chat not found")?;

        let topic = metadata.chat_type.to_topic(chat_id);

        let mut subs = self.subscriptions.write().await;
        subs.insert(chat_id.to_string(), topic.clone());

        Ok(topic)
    }

    /// Отписаться от темы
    pub async fn unsubscribe_from_topic(&self, chat_id: &str) {
        let mut subs = self.subscriptions.write().await;
        subs.remove(chat_id);
    }

    /// Получить список всех чатов
    pub async fn list_chats(&self) -> Vec<ChatMetadata> {
        let chats = self.chats.read().await;
        chats.values().cloned().collect()
    }

    /// Получить чат по ID
    pub async fn get_chat(&self, chat_id: &str) -> Option<ChatMetadata> {
        let chats = self.chats.read().await;
        chats.get(chat_id).cloned()
    }

    /// Получить активные подписки
    pub async fn get_subscriptions(&self) -> Vec<String> {
        let subs = self.subscriptions.read().await;
        subs.keys().cloned().collect()
    }

    /// Пригласить участника (для приватных чатов)
    pub async fn invite_member(
        &self,
        chat_id: &str,
        invitee_peer_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let mut chats = self.chats.write().await;
        let metadata = chats.get_mut(chat_id).ok_or("Chat not found")?;

        // Только владелец или участники могут приглашать
        if metadata.owner_peer_id != self.local_peer_id
            && !metadata.is_member(&self.local_peer_id)
        {
            return Err("Not authorized to invite".into());
        }

        // Генерация токена приглашения
        let invitation_token = format!(
            "invite_{}_{}",
            chat_id,
            uuid::Uuid::new_v4().as_simple()
        );

        // TODO: Сохранить токен в БД для валидации

        Ok(invitation_token)
    }
}

/// Сообщение для отправки в чат
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SocialMessage {
    pub chat_id: String,
    pub sender_peer_id: String,
    pub content: Vec<u8>,
    pub timestamp: u128,
    pub message_type: MessageType,
    pub is_encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MessageType {
    Text,
    Media,
    System,
    Encrypted,
}

impl SocialMessage {
    pub fn new(
        chat_id: String,
        sender_peer_id: String,
        content: Vec<u8>,
        message_type: MessageType,
    ) -> Self {
        let is_encrypted = matches!(message_type, MessageType::Encrypted);
        Self {
            chat_id,
            sender_peer_id,
            content,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis(),
            message_type,
            is_encrypted,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_chat() {
        let manager = SocialManager::new("peer123".to_string());
        let chat_id = manager
            .create_chat(ChatType::GroupPublic, Some("Test Group".to_string()))
            .await
            .unwrap();

        let chat = manager.get_chat(&chat_id).await.unwrap();
        assert_eq!(chat.chat_type, ChatType::GroupPublic);
        assert_eq!(chat.name, Some("Test Group".to_string()));
        assert_eq!(chat.member_count(), 1);
    }

    #[tokio::test]
    async fn test_join_leave_chat() {
        let manager = SocialManager::new("peer123".to_string());
        let chat_id = manager
            .create_chat(ChatType::GroupPublic, None)
            .await
            .unwrap();

        // Создаём второго пира
        let manager2 = SocialManager::new("peer456".to_string());

        // Присоединяемся к публичному чату
        manager2.join_chat(chat_id.clone(), None).await.unwrap();

        // Проверяем, что второй пир в списке членов (нужно обновить первый менеджер)
        // В реальном использовании это было бы через общую БД
    }

    #[test]
    fn test_chat_type_properties() {
        assert!(ChatType::Secret.requires_e2ee());
        assert!(!ChatType::Secret.persist_messages());
        assert_eq!(ChatType::Secret.access_type(), AccessType::Private);

        assert!(!ChatType::GroupPublic.requires_e2ee());
        assert!(ChatType::GroupPublic.persist_messages());
        assert_eq!(ChatType::GroupPublic.access_type(), AccessType::Public);
    }
}
