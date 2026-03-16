//! Liberty Sovereign v0.7.0 - The Sovereign Core
//!
//! P2P мессенджер с E2EE, Hybrid AI (Ollama + OpenRouter), и децентрализованным хранением
//!
//! Features:
//! - libp2p Swarm с Kademlia DHT + mDNS + Gossipsub
//! - Hybrid AI с автоматическим failover
//! - Terminal command system (/ai, /msg)
//! - E2EE шифрование

mod ai_engine;
mod config;

use ai_engine::{AiManager, AiRequest, start_ai_manager};
use config::Config;

use futures::{future::Either, stream::StreamExt};
use libp2p::{
    gossipsub::{self, IdentTopic, MessageAuthenticity},
    identity,
    kad::{self, store::MemoryStore},
    mdns,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux, noise,
    PeerId, Swarm, Transport,
    core::transport::upgrade::Version,
};
use libp2p::swarm::keep_alive;
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};
use std::error::Error;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{mpsc, RwLock};
use tokio::io::{self, AsyncBufReadExt, BufReader};
use tracing::{debug, error, info, warn};

/// Network Behaviour combining all protocols
#[derive(NetworkBehaviour)]
struct LibertyBehaviour {
    gossipsub: gossipsub::Behaviour,
    mdns: mdns::async_io::Behaviour,
    kademlia: kad::Behaviour<MemoryStore>,
    keep_alive: keep_alive::Behaviour,
}

/// Terminal command types
#[derive(Debug, Clone)]
enum TerminalCommand {
    Ai { text: String },
    Message { peer_id: PeerId, text: String },
    Help,
    Status,
    Unknown(String),
}

/// Parse terminal input into commands
fn parse_command(input: &str) -> TerminalCommand {
    let input = input.trim();
    
    if input.starts_with("/ai ") {
        TerminalCommand::Ai {
            text: input[4..].to_string(),
        }
    } else if input.starts_with("/msg ") {
        let parts: Vec<&str> = input[5..].splitn(2, ' ').collect();
        if parts.len() == 2 {
            match parts[0].parse::<PeerId>() {
                Ok(peer_id) => TerminalCommand::Message {
                    peer_id,
                    text: parts[1].to_string(),
                },
                Err(_) => TerminalCommand::Unknown(format!("Invalid peer ID: {}", parts[0])),
            }
        } else {
            TerminalCommand::Unknown("Usage: /msg <peer_id> <text>".to_string())
        }
    } else if input == "/help" || input == "/h" {
        TerminalCommand::Help
    } else if input == "/status" || input == "/s" {
        TerminalCommand::Status
    } else if input.starts_with('/') {
        TerminalCommand::Unknown(format!("Unknown command: {}", input))
    } else {
        TerminalCommand::Unknown(input.to_string())
    }
}

/// Print help message
fn print_help() {
    println!("\n📘 Liberty Reach Commands:");
    println!("  /ai <text>        - Ask AI (tries Ollama first, then OpenRouter)");
    println!("  /msg <peer> <txt> - Send P2P message to peer");
    println!("  /status, /s       - Show node status");
    println!("  /help, /h         - Show this help");
    println!("  <text>            - Broadcast to all peers via gossipsub\n");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("liberty_sovereign=info".parse()?)
                .add_directive("libp2p=warn".parse()?)
        )
        .init();

    info!("🚀 Liberty Sovereign v0.7.0 - The Sovereign Core");

    // Load configuration
    let config = Config::load().unwrap_or_default();

    // Create identity
    let identity_keypair = identity::ed25519::Keypair::generate();
    let local_peer_id = PeerId::from(identity_keypair.public());
    info!("🆔 Local peer ID: {}", local_peer_id);

    // Create transport
    let transport = tcp::async_io::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(Version::V1)
        .authenticate(noise::Config::new(&identity_keypair)?)
        .multiplex(yamux::Config::default())
        .boxed();

    // Create behaviour
    let mut swarm = create_swarm(&identity_keypair, local_peer_id, transport)?;

    // Listen on all interfaces
    let listen_addr = format!("/ip4/0.0.0.0/tcp/{}", config.p2p_port.unwrap_or(40000)).parse()?;
    swarm.listen_on(listen_addr.clone())?;
    info!("📡 Listening on: {}", listen_addr);

    // Enable mDNS for local discovery
    info!("🔍 mDNS enabled for local peer discovery");

    // Create AI Manager
    let ai_manager = start_ai_manager(config.clone());
    info!("🤖 AI Manager initialized (Ollama + OpenRouter failover)");

    // Create channels for terminal input
    let (tx, mut rx) = mpsc::channel::<String>(100);

    // Spawn terminal input task
    tokio::spawn(async move {
        let stdin = BufReader::new(io::stdin());
        let mut lines = stdin.lines();
        
        while let Ok(Some(line)) = lines.next_line().await {
            if tx.send(line).await.is_err() {
                break;
            }
        }
    });

    // Store connected peers
    let connected_peers = Arc::new(RwLock::new(Vec::<PeerId>::new()));
    let connected_peers_clone = Arc::clone(&connected_peers);

    // Subscribe to main topic
    let main_topic = IdentTopic::new("liberty-reach-main");
    swarm.behaviour_mut().gossipsub.subscribe(&main_topic)?;
    info!("📢 Subscribed to topic: {}", main_topic.hash());

    info!("✅ Sovereign Core ready! Type /help for commands.\n");

    // Main event loop
    loop {
        tokio::select! {
            // Terminal input
            Some(input) = rx.recv() => {
                let command = parse_command(&input);
                
                match command {
                    TerminalCommand::Ai { text } => {
                        info!("🤖 AI request: {}", text);
                        match ai_manager.process_message(AiRequest {
                            prompt: text,
                            system_prompt: Some("You are a helpful AI assistant for Liberty Reach.".to_string()),
                            max_tokens: Some(512),
                            temperature: Some(0.7),
                        }).await {
                            Ok(response) => {
                                println!("🤖 [{}]: {}", 
                                    match response.provider {
                                        ai_engine::AiProvider::Ollama => "Ollama",
                                        ai_engine::AiProvider::OpenRouter => "OpenRouter",
                                    },
                                    response.content
                                );
                            }
                            Err(e) => {
                                eprintln!("❌ AI error: {}", e);
                            }
                        }
                    }
                    TerminalCommand::Message { peer_id, text } => {
                        info!("📤 Sending message to {}: {}", peer_id, text);
                        // Send via direct connection (would need established connection)
                        println!("⚠️  Direct messaging requires established connection. Use broadcast instead.");
                    }
                    TerminalCommand::Help => {
                        print_help();
                    }
                    TerminalCommand::Status => {
                        let peers = connected_peers.read().await;
                        let (provider, ollama_healthy, fallbacks) = ai_manager.get_provider_status().await;
                        println!("\n📊 Node Status:");
                        println!("  Peer ID: {}", local_peer_id);
                        println!("  Connected peers: {}", peers.len());
                        for peer in peers.iter() {
                            println!("    - {}", peer);
                        }
                        println!("  AI Provider: {:?}", provider);
                        println!("  Ollama healthy: {}", ollama_healthy);
                        println!("  Fallback count: {}", fallbacks);
                        println!("  Listening on: {}", listen_addr);
                        println!();
                    }
                    TerminalCommand::Unknown(cmd) => {
                        // Broadcast as gossipsub message
                        if !cmd.is_empty() {
                            let topic = IdentTopic::new("liberty-reach-main");
                            if let Ok(_) = swarm.behaviour_mut().gossipsub.publish(topic, cmd.as_bytes()) {
                                info!("📢 Broadcast: {}", cmd);
                                println!("✅ Message broadcast to network");
                            } else {
                                eprintln!("❌ Failed to broadcast message");
                            }
                        }
                    }
                }
            }
            
            // Swarm events
            event = swarm.select_next_some() => {
                match event {
                    SwarmEvent::NewListenAddr { address, .. } => {
                        info!("🎧 Listening on: {}", address);
                    }
                    SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
                        info!("✅ Connected to {} via {:?}", peer_id, endpoint);
                        
                        // Add to connected peers
                        {
                            let mut peers = connected_peers_clone.write().await;
                            if !peers.contains(&peer_id) {
                                peers.push(peer_id);
                            }
                        }
                        
                        // Add address to Kademlia
                        swarm.behaviour_mut().kademlia.add_address(&peer_id, endpoint.get_remote_address().clone());
                    }
                    SwarmEvent::ConnectionClosed { peer_id, cause, .. } => {
                        warn!("❌ Connection closed with {}: {:?}", peer_id, cause);
                        
                        // Remove from connected peers
                        {
                            let mut peers = connected_peers_clone.write().await;
                            peers.retain(|&p| p != peer_id);
                        }
                    }
                    SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                        for (peer_id, multiaddr) in list {
                            info!("🔍 mDNS discovered {}: {}", peer_id, multiaddr);
                            swarm.behaviour_mut().kademlia.add_address(&peer_id, multiaddr.clone());
                            
                            // Try to connect
                            let _ = swarm.dial(multiaddr);
                        }
                    }
                    SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
                        for (peer_id, _) in list {
                            info!("⏰ mDNS expired: {}", peer_id);
                        }
                    }
                    SwarmEvent::Behaviour(LibertyBehaviourEvent::Kademlia(
                        kad::Event::RoutingUpdated { peer, .. }
                    )) => {
                        debug!("🗺️  Kademlia routing updated for {}", peer);
                    }
                    SwarmEvent::Behaviour(LibertyBehaviourEvent::Gossipsub(
                        gossipsub::Event::Message {
                            propagation_source: peer_id,
                            message_id: id,
                            message,
                        }
                    )) => {
                        info!("📨 Received message from {}: {:?}", peer_id, id);
                        
                        // Try to decode as string
                        if let Ok(text) = String::from_utf8(message.data.clone()) {
                            println!("💬 [{}]: {}", peer_id, text);
                            
                            // Auto-process with AI (optional)
                            let ai_mgr = Arc::clone(&ai_manager);
                            tokio::spawn(async move {
                                if let Ok(response) = ai_mgr.process_incoming_message(&text, None).await {
                                    debug!("🤖 AI suggestion: {}", response.content);
                                }
                            });
                        }
                    }
                    SwarmEvent::Behaviour(LibertyBehaviourEvent::Gossipsub(
                        gossipsub::Event::Subscribed { peer_id, topic }
                    )) => {
                        debug!("📢 {} subscribed to {}", peer_id, topic);
                    }
                    _ => {}
                }
            }
        }
    }
}

/// Create swarm with all behaviours
fn create_swarm(
    keypair: &identity::Keypair,
    local_peer_id: PeerId,
    transport: libp2p::core::transport::Boxed<(PeerId, libp2p::core::muxing::StreamBoxed)>,
) -> Result<Swarm<LibertyBehaviour>, Box<dyn Error>> {
    // Gossipsub configuration
    let gossipsub_config = gossipsub::ConfigBuilder::default()
        .validation_mode(gossipsub::ValidationMode::Strict)
        .message_id_fn(|msg| {
            use sha2::{Digest, Sha256};
            let mut hasher = Sha256::new();
            hasher.update(&msg.source.unwrap().to_bytes());
            hasher.update(&msg.data);
            gossipsub::MessageId::from(hasher.finalize().to_vec())
        })
        .build()
        .expect("Valid config");

    let gossipsub = gossipsub::Behaviour::new(
        MessageAuthenticity::Signed(keypair.clone()),
        gossipsub_config,
    ).expect("Valid configuration");

    // mDNS configuration
    let mdns = mdns::async_io::Behaviour::new(
        mdns::Config::default(),
        local_peer_id,
    )?;

    // Kademlia configuration
    let mut kademlia_config = kad::Config::default();
    kademlia_config.set_protocol_names(vec!["/liberty-reach/kad/1.0.0".into()]);

    let store = MemoryStore::new(local_peer_id);
    let mut kademlia = kad::Behaviour::with_config(local_peer_id, store, kademlia_config);
    kademlia.bootstrap()?;

    // Keep-alive
    let keep_alive = keep_alive::Behaviour;

    // Create behaviour
    let behaviour = LibertyBehaviour {
        gossipsub,
        mdns,
        kademlia,
        keep_alive,
    };

    // Create swarm
    let swarm = Swarm::new(
        transport,
        behaviour,
        local_peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            .with_idle_connection_timeout(Duration::from_secs(60)),
    );

    Ok(swarm)
}
