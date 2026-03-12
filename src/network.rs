//! Сетевой модуль Liberty Reach
//!
//! Реализует P2P поведение на базе libp2p:
//! - Gossipsub: рассылка сообщений
//! - Kademlia: DHT для поиска узлов
//! - mDNS: локальное обнаружение
//! - Identify: обмен информацией об узлах (требуется для Relay/Kademlia)
//! - Relay: переподключение через узлы за NAT
//! - AutoNAT: определение типа NAT
//! - DCUtR: прямое соединение через NAT

use libp2p::{
    gossipsub, kad, mdns, relay, autonat, dcutr, identify,
    swarm::NetworkBehaviour,
};

/// Основное поведение сети Liberty Reach
///
/// #[derive(NetworkBehaviour)] автоматически генерирует:
/// - LibertyBehaviourEvent — перечисление событий
/// - Реализацию NetworkBehaviour
#[derive(NetworkBehaviour)]
pub struct LibertyBehaviour {
    /// Gossipsub для публикации сообщений
    pub gossipsub: gossipsub::Behaviour,
    /// Kademlia DHT для поиска узлов
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    /// mDNS для локального обнаружения
    pub mdns: mdns::tokio::Behaviour,
    /// Identify для обмена информацией об узлах
    pub identify: identify::Behaviour,
    /// Relay клиент для NAT traversal
    pub relay_client: relay::client::Behaviour,
    /// AutoNAT для определения типа NAT
    pub autonat: autonat::Behaviour,
    /// DCUtR для прямого соединения через NAT
    pub dcutr: dcutr::Behaviour,
}

/// Имя основного топика для сообщений
pub const TOPIC_NAME: &str = "liberty-chat";

/// Топик для обмена ключами Diffie-Hellman
pub const KEY_EXCHANGE_TOPIC: &str = "liberty-key-exchange";

impl LibertyBehaviour {
    /// Создание нового поведения
    pub fn new(
        key: &libp2p::identity::Keypair,
        gossipsub_config: gossipsub::Config,
        relay: relay::client::Behaviour,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let peer_id = key.public().to_peer_id();
        let public_key = key.public();

        Ok(Self {
            gossipsub: gossipsub::Behaviour::new(
                gossipsub::MessageAuthenticity::Signed(key.clone()),
                gossipsub_config,
            )?,
            kademlia: kad::Behaviour::new(
                peer_id,
                kad::store::MemoryStore::new(peer_id),
            ),
            mdns: mdns::tokio::Behaviour::new(
                mdns::Config::default(),
                peer_id,
            )?,
            identify: identify::Behaviour::new(
                identify::Config::new(
                    "/liberty-reach/1.0.0".to_string(),
                    public_key,
                )
                .with_push_listen_addr_updates(true),
            ),
            relay_client: relay,
            autonat: autonat::Behaviour::new(
                peer_id,
                autonat::Config::default(),
            ),
            dcutr: dcutr::Behaviour::new(peer_id),
        })
    }

    /// Подписка на основной топик
    pub fn subscribe_main_topic(
        &mut self
    ) -> Result<bool, gossipsub::SubscriptionError> {
        self.gossipsub.subscribe(&gossipsub::IdentTopic::new(TOPIC_NAME))
    }

    /// Подписка на топик обмена ключами
    pub fn subscribe_key_exchange_topic(
        &mut self
    ) -> Result<bool, gossipsub::SubscriptionError> {
        self.gossipsub.subscribe(&gossipsub::IdentTopic::new(KEY_EXCHANGE_TOPIC))
    }
}

/// Создание конфигурации Gossipsub с кастомным message_id_fn
pub fn create_gossipsub_config() -> Result<gossipsub::Config, gossipsub::ConfigBuilderError> {
    let message_id_fn = |message: &gossipsub::Message| {
        use std::hash::Hash;
        let mut s = std::collections::hash_map::DefaultHasher::new();
        message.data.hash(&mut s);
        gossipsub::MessageId::from(std::hash::Hasher::finish(&s).to_string().into_bytes())
    };

    gossipsub::ConfigBuilder::default()
        .message_id_fn(message_id_fn)
        .validate_messages() // Включаем валидацию для безопасности
        .build()
}
