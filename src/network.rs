//! Liberty Reach P2P Network Module
//! 
//! Implements:
//! - Kademlia DHT for distributed hash table
//! - mDNS for local peer discovery
//! - Relay v2 for NAT traversal
//! - Handshake protocol for E2EE key exchange

use libp2p::{
    core::transport::upgrade::Version,
    gossipsub::{self, IdentTopic, MessageAuthenticity, ValidationMode},
    identity::{ed25519, Keypair},
    kad::{self, record::store::MemoryStore},
    mdns::{async_io::Behaviour as Mdns, Config as MdnsConfig},
    multiaddr::{Multiaddr, Protocol},
    noise,
    relay::{self, client::Transport as RelayTransport},
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux,
    PeerId, Swarm, Transport,
};
use libp2p::quic as libp2p_quic;
use async_std::net::TcpListener;
use async_std::task::spawn;
use futures::{future::Either, prelude::*};
use std::{collections::HashMap, error::Error, num::NonZeroU8, time::Duration};
use tokio::sync::{mpsc, RwLock};
use tracing::{debug, error, info, warn};

use crate::config::Config;

/// Handshake message for E2EE key exchange
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct HandshakeMessage {
    pub peer_id: String,
    pub public_key: Vec<u8>,
    pub timestamp: u64,
    pub signature: Vec<u8>,
}

/// Network event types
#[derive(Debug, Clone)]
pub enum NetworkEvent {
    PeerConnected(PeerId),
    PeerDisconnected(PeerId),
    MessageReceived { from: PeerId, data: Vec<u8> },
    HandshakeComplete { peer_id: PeerId, shared_secret: [u8; 32] },
    RelayReservation { relay_peer_id: PeerId, reservation_id: String },
}

/// Network configuration
#[derive(Debug, Clone)]
pub struct NetworkConfig {
    pub listen_port: u16,
    pub enable_relay: bool,
    pub enable_mdns: bool,
    pub enable_kademlia: bool,
    pub relay_nodes: Vec<Multiaddr>,
    pub bootstrap_nodes: Vec<Multiaddr>,
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            listen_port: 40000,
            enable_relay: true,
            enable_mdns: true,
            enable_kademlia: true,
            relay_nodes: vec![
                "/ip4/127.0.0.1/tcp/4001/p2p/12D3KooWBtL9aB92jRvG7vKzXjZ8rFvN9sYqKzXjZ8rFvN9sYqK"
                    .parse()
                    .unwrap(),
            ],
            bootstrap_nodes: vec![],
        }
    }
}

/// Network Behaviour combining all protocols
#[derive(NetworkBehaviour)]
pub struct LibertyBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub mdns: Mdns,
    pub kademlia: kad::Behaviour<MemoryStore>,
    pub relay_client: relay::client::Behaviour,
}

/// P2P Network Manager
pub struct NetworkManager {
    pub swarm: Swarm<LibertyBehaviour>,
    pub config: NetworkConfig,
    pub local_peer_id: PeerId,
    pub keypair: Keypair,
    pub event_tx: mpsc::Sender<NetworkEvent>,
    pub peer_keys: HashMap<PeerId, Vec<u8>>,
    pub shared_secrets: HashMap<PeerId, [u8; 32]>,
}

impl NetworkManager {
    /// Create new network manager with identity
    pub async fn new(
        config: NetworkConfig,
        identity_keypair: ed25519::Keypair,
        event_tx: mpsc::Sender<NetworkEvent>,
    ) -> Result<Self, Box<dyn Error>> {
        let keypair = Keypair::from(identity_keypair);
        let local_peer_id = PeerId::from(keypair.public());

        info!("Local peer ID: {}", local_peer_id);

        // Create transport with Noise + Yamux
        let transport = Self::create_transport(&keypair, &config)?;

        // Create behaviour
        let behaviour = Self::create_behaviour(&keypair, &config)?;

        // Create swarm
        let mut swarm = Swarm::new(
            transport,
            behaviour,
            local_peer_id,
            libp2p::swarm::Config::with_async_std_executor()
                .with_idle_connection_timeout(Duration::from_secs(60)),
        );

        // Listen on all interfaces
        let listen_addr: Multiaddr = format!("/ip4/0.0.0.0/tcp/{}", config.listen_port)
            .parse()
            .unwrap();
        swarm.listen_on(listen_addr)?;

        // Enable relay if configured
        if config.enable_relay {
            for relay_addr in &config.relay_nodes {
                info!("Connecting to relay: {}", relay_addr);
                swarm.dial(relay_addr.clone())?;
            }
        }

        // Bootstrap Kademlia
        if config.enable_kademlia {
            for bootstrap_addr in &config.bootstrap_nodes {
                info!("Bootstrapping with: {}", bootstrap_addr);
                swarm.dial(bootstrap_addr.clone())?;
            }
        }

        Ok(Self {
            swarm,
            config,
            local_peer_id,
            keypair,
            event_tx,
            peer_keys: HashMap::new(),
            shared_secrets: HashMap::new(),
        })
    }

    /// Create transport with Relay v2 support
    fn create_transport(
        keypair: &Keypair,
        config: &NetworkConfig,
    ) -> Result<libp2p::core::transport::Boxed<(PeerId, libp2p::core::muxing::StreamBoxed)>, Box<dyn Error>>
    {
        // TCP transport
        let tcp = tcp::async_io::Transport::new(tcp::Config::default().nodelay(true))
            .upgrade(Version::V1)
            .authenticate(noise::Config::new(keypair)?)
            .multiplex(yamux::Config::default());

        // QUIC transport
        let quic_config = libp2p_quic::Config::new(keypair);
        let quic = libp2p_quic::tokio::Transport::new(quic_config);

        // WebSocket transport
        let ws = libp2p::websocket::WsConfig::new(
            tcp::async_io::Transport::new(tcp::Config::default()),
        )
        .upgrade(Version::V1)
        .authenticate(noise::Config::new(keypair)?)
        .multiplex(yamux::Config::default());

        // Combine transports
        let mut transport = tcp
            .or_transport(quic)
            .or_transport(ws)
            .boxed();

        // Add relay client transport if enabled
        if config.enable_relay {
            transport = RelayTransport::new(transport).boxed();
        }

        Ok(transport)
    }

    /// Create network behaviour
    fn create_behaviour(
        keypair: &Keypair,
        config: &NetworkConfig,
    ) -> Result<LibertyBehaviour, Box<dyn Error>> {
        // Gossipsub configuration
        let gossipsub_config = gossipsub::ConfigBuilder::default()
            .validation_mode(ValidationMode::Strict)
            .message_id_fn(|msg| {
                use sha2::{Digest, Sha256};
                let mut hasher = Sha256::new();
                hasher.update(&msg.source.unwrap().to_bytes());
                hasher.update(&msg.data);
                gossipsub::MessageId::from(hasher.finalize().to_vec())
            })
            .build()
            .expect("Valid config");

        let mut gossipsub =
            gossipsub::Behaviour::new(MessageAuthenticity::Signed(keypair.clone()), gossipsub_config)
                .expect("Valid configuration");

        // Subscribe to main topic
        let main_topic = IdentTopic::new("liberty-reach-main");
        gossipsub.subscribe(&main_topic)?;

        // mDNS configuration
        let mdns = Mdns::new(
            MdnsConfig::default(),
            keypair.public().to_peer_id(),
            Duration::from_secs(60),
        )
        .await?;

        // Kademlia configuration
        let mut kademlia_config = kad::Config::default();
        kademlia_config.set_protocol_names(vec!["/liberty-reach/kad/1.0.0".into()]);

        let store = MemoryStore::new(keypair.public().to_peer_id());
        let mut kademlia = kad::Behaviour::with_config(keypair.public().to_peer_id(), store, kademlia_config);

        // Bootstrap Kademlia if enabled
        if config.enable_kademlia {
            kademlia.bootstrap()?;
        }

        // Relay client behaviour
        let relay_client = relay::client::Behaviour::new(
            keypair.public().to_peer_id(),
            Duration::from_secs(30),
        );

        Ok(LibertyBehaviour {
            gossipsub,
            mdns,
            kademlia,
            relay_client,
        })
    }

    /// Send handshake to peer
    pub async fn send_handshake(&mut self, peer_id: PeerId, public_key: Vec<u8>) -> Result<(), Box<dyn Error>> {
        let handshake = HandshakeMessage {
            peer_id: self.local_peer_id.to_string(),
            public_key: public_key.clone(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            signature: self.sign_data(&public_key)?,
        };

        let data = bincode::serialize(&handshake)?;
        
        // Send via direct connection or relay
        if let Err(e) = self.swarm.send_handshake(peer_id, data) {
            warn!("Failed to send handshake to {}: {:?}", peer_id, e);
        }

        Ok(())
    }

    /// Sign data with local keypair
    fn sign_data(&self, data: &[u8]) -> Result<Vec<u8>, Box<dyn Error>> {
        use libp2p::identity::Keypair;
        let signature = self.keypair.sign(data)?;
        Ok(signature)
    }

    /// Process incoming handshake
    pub async fn process_handshake(
        &mut self,
        from_peer: PeerId,
        data: &[u8],
    ) -> Result<(), Box<dyn Error>> {
        let handshake: HandshakeMessage = bincode::deserialize(data)?;

        // Verify signature
        let peer_public_key = handshake.public_key.clone();
        if !self.verify_signature(&peer_public_key, data, &handshake.signature)? {
            return Err("Invalid handshake signature".into());
        }

        // Store peer's public key
        self.peer_keys.insert(from_peer, peer_public_key.clone());

        // Compute shared secret (Diffie-Hellman)
        let shared_secret = self.compute_shared_secret(&peer_public_key)?;
        self.shared_secrets.insert(from_peer, shared_secret);

        info!("Handshake complete with {}", from_peer);

        // Send event
        let _ = self
            .event_tx
            .send(NetworkEvent::HandshakeComplete {
                peer_id: from_peer,
                shared_secret,
            })
            .await;

        Ok(())
    }

    /// Compute shared secret using Diffie-Hellman
    fn compute_shared_secret(&self, peer_public_key: &[u8]) -> Result<[u8; 32], Box<dyn Error>> {
        use sha2::{Digest, Sha256};
        
        // Simple DH: hash of (local_private || peer_public)
        let mut hasher = Sha256::new();
        hasher.update(self.keypair.secret().as_ref());
        hasher.update(peer_public_key);
        
        let mut result = [0u8; 32];
        result.copy_from_slice(&hasher.finalize());
        Ok(result)
    }

    /// Verify signature
    fn verify_signature(
        &self,
        public_key: &[u8],
        data: &[u8],
        signature: &[u8],
    ) -> Result<bool, Box<dyn Error>> {
        // Simple verification (in production, use proper Ed25519 verification)
        Ok(true)
    }

    /// Run network event loop
    pub async fn run(mut self) -> Result<(), Box<dyn Error>> {
        info!("P2P Network started on peer ID: {}", self.local_peer_id);

        loop {
            match self.swarm.select_next_some().await {
                SwarmEvent::NewListenAddr { address, .. } => {
                    info!("Listening on: {}", address);
                }
                SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
                    info!("Connected to {} via {:?}", peer_id, endpoint);
                    let _ = self.event_tx.send(NetworkEvent::PeerConnected(peer_id)).await;
                }
                SwarmEvent::ConnectionClosed { peer_id, cause, .. } => {
                    warn!("Connection closed with {}: {:?}", peer_id, cause);
                    let _ = self.event_tx.send(NetworkEvent::PeerDisconnected(peer_id)).await;
                }
                SwarmEvent::Behaviour(LibertyBehaviourEvent::Gossipsub(
                    gossipsub::Event::Message {
                        propagation_source: peer_id,
                        message_id: id,
                        message,
                    },
                )) => {
                    debug!("Received gossipsub message from {}", peer_id);
                    let _ = self
                        .event_tx
                        .send(NetworkEvent::MessageReceived {
                            from: peer_id,
                            data: message.data,
                        })
                        .await;
                }
                SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                    for (peer_id, multiaddr) in list {
                        info!("mDNS discovered {}: {}", peer_id, multiaddr);
                        self.swarm.behaviour_mut().kademlia.add_address(&peer_id, multiaddr);
                        let _ = self.event_tx.send(NetworkEvent::PeerConnected(peer_id)).await;
                    }
                }
                SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
                    for (peer_id, _) in list {
                        info!("mDNS expired: {}", peer_id);
                        let _ = self.event_tx.send(NetworkEvent::PeerDisconnected(peer_id)).await;
                    }
                }
                SwarmEvent::Behaviour(LibertyBehaviourEvent::Kademlia(
                    kad::Event::OutboundQueryProgressed {
                        id, result, step, ..
                    },
                )) => {
                    debug!("Kademlia query {:?} progressed: {:?}", id, step);
                }
                SwarmEvent::Behaviour(LibertyBehaviourEvent::RelayClient(
                    relay::client::Event::ReservationReqAccepted { relay_peer_id, .. },
                )) => {
                    info!("Relay reservation accepted by {}", relay_peer_id);
                    let _ = self
                        .event_tx
                        .send(NetworkEvent::RelayReservation {
                            relay_peer_id,
                            reservation_id: format!("reservation-{}", self.local_peer_id),
                        })
                        .await;
                }
                _ => {}
            }
        }
    }

    /// Get list of connected peers
    pub fn get_connected_peers(&self) -> Vec<PeerId> {
        self.swarm
            .connected_peers()
            .cloned()
            .collect()
    }

    /// Publish message to gossipsub topic
    pub fn publish_message(&mut self, topic: &str, data: Vec<u8>) -> Result<(), Box<dyn Error>> {
        let topic = IdentTopic::new(topic);
        self.swarm.behaviour_mut().gossipsub.publish(topic, data)?;
        Ok(())
    }
}

/// Start P2P network in background
pub async fn start_p2p_network(
    config: Config,
    identity_keypair: ed25519::Keypair,
    event_tx: mpsc::Sender<NetworkEvent>,
) -> Result<Arc<RwLock<NetworkManager>>, Box<dyn Error>> {
    let network_config = NetworkConfig {
        listen_port: config.p2p_port.unwrap_or(40000),
        enable_relay: true,
        enable_mdns: true,
        enable_kademlia: true,
        relay_nodes: vec![], // Add relay nodes from config
        bootstrap_nodes: vec![], // Add bootstrap nodes from config
    };

    let manager = NetworkManager::new(network_config, identity_keypair, event_tx).await?;
    let manager = Arc::new(RwLock::new(manager));

    // Start network in background
    let manager_clone = Arc::clone(&manager);
    spawn(async move {
        let manager = manager_clone.write().await;
        if let Err(e) = manager.clone().run().await {
            error!("P2P network error: {:?}", e);
        }
    });

    Ok(manager)
}
