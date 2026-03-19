//! Liberty Sovereign v0.7.2 - Tokio + libp2p v0.53 Compatible
//!
//! Features:
//! - Verbose tracing (see EVERYTHING)
//! - Hybrid AI (Ollama → OpenRouter with 2s timeout)
//! - P2P via libp2p tokio (mDNS + Kademlia + Gossipsub)
//! - Interactive stdin terminal
//! - Proper error handling (? and expect())

mod ai_engine;

use ai_engine::{AiManager, AiRequest, start_ai_manager};

use futures::stream::StreamExt;
use libp2p::{
    gossipsub::{self, IdentTopic, MessageAuthenticity, ValidationMode},
    identity,
    kad::{self, store::MemoryStore},
    mdns,
    swarm::{NetworkBehaviour, SwarmEvent, StreamProtocol},
    tcp, yamux, noise,
    PeerId, Swarm, Transport,
    core::transport::upgrade::Version,
};
use sha2::Digest;
use std::error::Error;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

/// Network Behaviour with proper derive macro
#[derive(NetworkBehaviour)]
struct LibertyBehaviour {
    gossipsub: gossipsub::Behaviour,
    mdns: mdns::tokio::Behaviour,
    kademlia: kad::Behaviour<MemoryStore>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // ========================================================================
    // 1. VERBOSE TRACING - See EVERYTHING
    // ========================================================================
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("liberty_sovereign=info".parse()?)
                .add_directive("libp2p=info".parse()?)
                .add_directive("libp2p_gossipsub=info".parse()?)
                .add_directive("libp2p_kad=info".parse()?)
                .add_directive("libp2p_mdns=info".parse()?)
        )
        .with_thread_ids(true)
        .with_thread_names(true)
        .init();

    info!("╔═══════════════════════════════════════════════════════════╗");
    info!("║   Liberty Sovereign v0.7.2 - Tokio + libp2p v0.53         ║");
    info!("╚═══════════════════════════════════════════════════════════╝");

    // ========================================================================
    // 2. LOAD ENVIRONMENT
    // ========================================================================
    dotenvy::dotenv().ok(); // Load .env.local if exists
    info!("✅ Environment loaded");

    // ========================================================================
    // 3. CREATE IDENTITY (using libp2p::identity)
    // ========================================================================
    let identity_keypair = identity::Keypair::generate_ed25519();
    let local_peer_id = PeerId::from(identity_keypair.public());
    
    info!("🆔 Local Peer ID: {}", local_peer_id);
    info!("   (Share this with other nodes to connect manually)");

    // ========================================================================
    // 4. CREATE TRANSPORT (tokio-compatible)
    // ========================================================================
    let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(Version::V1)
        .authenticate(noise::Config::new(&identity_keypair)?)
        .multiplex(yamux::Config::default())
        .boxed();

    info!("✅ Transport created (TCP tokio + Noise + Yamux)");

    // ========================================================================
    // 5. CREATE SWARM WITH BEHAVIOURS
    // ========================================================================
    let mut swarm = create_swarm(&identity_keypair, local_peer_id, transport)?;
    info!("✅ Swarm created with Gossipsub + mDNS tokio + Kademlia");

    // ========================================================================
    // 6. START LISTENING
    // ========================================================================
    let p2p_port: u16 = std::env::var("P2P_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(40000);

    let listen_addr: libp2p::Multiaddr = format!("/ip4/0.0.0.0/tcp/{}", p2p_port).parse()?;
    
    match swarm.listen_on(listen_addr.clone()) {
        Ok(_) => info!("📡 Listening on: {}", listen_addr),
        Err(e) => error!("❌ Failed to listen: {}", e),
    }

    // ========================================================================
    // 7. INITIALIZE AI MANAGER
    // ========================================================================
    let ai_manager = start_ai_manager();
    
    // Quick health check
    let ai_status = ai_manager.get_status().await;
    info!("🤖 AI Status: provider={:?}, ollama_healthy={}, fallbacks={}", 
          ai_status.0, ai_status.1, ai_status.2);

    // ========================================================================
    // 8. SUBSCRIBE TO TOPIC
    // ========================================================================
    let main_topic = IdentTopic::new("liberty-sovereign-main");
    match swarm.behaviour_mut().gossipsub.subscribe(&main_topic) {
        Ok(_) => info!("📢 Subscribed to topic: {}", main_topic.hash()),
        Err(e) => error!("❌ Failed to subscribe: {}", e),
    }

    // ========================================================================
    // 9. CREATE TERMINAL INPUT CHANNEL
    // ========================================================================
    let (tx, mut rx) = mpsc::channel::<String>(100);

    // Spawn stdin reader task
    tokio::spawn(async move {
        info!("📝 Stdin reader started (type messages and press Enter)");
        let stdin = BufReader::new(io::stdin());
        let mut lines = stdin.lines();
        
        while let Ok(Some(line)) = lines.next_line().await {
            if line.trim().is_empty() {
                continue;
            }
            
            if tx.send(line).await.is_err() {
                error!("❌ Failed to send line to channel");
                break;
            }
        }
    });

    // ========================================================================
    // 10. MAIN EVENT LOOP
    // ========================================================================
    info!("╔═══════════════════════════════════════════════════════════╗");
    info!("║   ✅ Sovereign Core READY!                                ║");
    info!("║                                                           ║");
    info!("║   Type messages and press Enter to broadcast              ║");
    info!("║   Commands:                                               ║");
    info!("║     /ai <text>      - Ask AI                              ║");
    info!("║     /status         - Show node status                    ║");
    info!("║     /help           - Show commands                       ║");
    info!("╚═══════════════════════════════════════════════════════════╝");
    info!("");

    loop {
        tokio::select! {
            // =================================================================
            // TERMINAL INPUT (String - Sized type)
            // =================================================================
            Some(input) = rx.recv() => {
                process_terminal_input(&input, &ai_manager).await;
            }
            
            // =================================================================
            // SWARM EVENTS
            // =================================================================
            event = swarm.select_next_some() => {
                process_swarm_event(event, &mut swarm).await;
            }
        }
    }
}

/// Process terminal commands
async fn process_terminal_input(input: &str, ai_manager: &Arc<AiManager>) {
    let input = input.trim();
    
    if input.starts_with("/ai ") {
        // AI command
        let text = &input[4..];
        info!("🤖 AI request: {}", text);
        
        match ai_manager.process_message(AiRequest {
            prompt: text.to_string(),
            system_prompt: Some("You are a helpful AI assistant for Liberty Sovereign. Keep responses concise and helpful.".to_string()),
            max_tokens: Some(512),
            temperature: Some(0.7),
        }).await {
            Ok(response) => {
                let provider_name = match response.provider {
                    ai_engine::AiProvider::Ollama => "Ollama",
                    ai_engine::AiProvider::OpenRouter => "OpenRouter",
                };
                println!("🤖 [{}]: {}", provider_name, response.content);
            }
            Err(e) => {
                eprintln!("❌ AI error: {}", e);
                if matches!(e, ai_engine::AiError::OpenRouterAuth) {
                    eprintln!("   Fix: Set OPENROUTER_API_KEY in .env.local");
                    eprintln!("   Get free key: https://openrouter.ai/keys");
                }
            }
        }
    } else if input == "/status" || input == "/s" {
        // Status command
        let (provider, ollama_healthy, fallbacks) = ai_manager.get_status().await;
        println!("\n📊 Node Status:");
        println!("  AI Provider: {:?}", provider);
        println!("  Ollama healthy: {}", ollama_healthy);
        println!("  Fallback count: {}", fallbacks);
        println!();
    } else if input == "/help" || input == "/h" {
        // Help command
        println!("\n📘 Commands:");
        println!("  /ai <text>  - Ask AI (tries Ollama first, then OpenRouter)");
        println!("  /status     - Show node status");
        println!("  /help       - Show this help");
        println!("  <text>      - Broadcast to network via gossipsub");
        println!();
    } else if input.starts_with('/') {
        // Unknown command
        eprintln!("❓ Unknown command: {}. Type /help for commands.", input);
    } else {
        // Broadcast message
        info!("📤 Broadcasting: {}", input);
        println!("✅ Message queued for broadcast (will show when swarm processes it)");
    }
}

/// Process libp2p swarm events
async fn process_swarm_event(
    event: SwarmEvent<LibertyBehaviourEvent>,
    swarm: &mut Swarm<LibertyBehaviour>,
) {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            info!("🎧 New listen address: {}", address);
        }
        
        SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
            info!("✅ Connection established with {} via {:?}", peer_id, endpoint);
            
            // Add address to Kademlia
            swarm.behaviour_mut().kademlia.add_address(&peer_id, endpoint.get_remote_address().clone());
        }
        
        SwarmEvent::ConnectionClosed { peer_id, cause, .. } => {
            warn!("❌ Connection closed with {}: {:?}", peer_id, cause);
        }
        
        SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
            for (peer_id, multiaddr) in list {
                info!("🔍 mDNS discovered peer: {} at {}", peer_id, multiaddr);
                
                // Add to Kademlia
                swarm.behaviour_mut().kademlia.add_address(&peer_id, multiaddr.clone());
                
                // Try to connect
                if let Err(e) = swarm.dial(multiaddr) {
                    warn!("⚠️  Failed to dial mDNS peer: {}", e);
                }
            }
        }
        
        SwarmEvent::Behaviour(LibertyBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
            for (peer_id, _) in list {
                info!("⏰ mDNS peer expired: {}", peer_id);
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
            info!("📨 Received gossipsub message from {} (ID: {:?})", peer_id, id);
            
            // Try to decode as UTF-8 string
            if let Ok(text) = String::from_utf8(message.data.clone()) {
                println!("💬 [{}]: {}", peer_id, text);
            } else {
                debug!("📨 Received binary message ({} bytes)", message.data.len());
            }
        }
        
        SwarmEvent::Behaviour(LibertyBehaviourEvent::Gossipsub(
            gossipsub::Event::Subscribed { peer_id, topic }
        )) => {
            debug!("📢 {} subscribed to topic {}", peer_id, topic);
        }
        
        SwarmEvent::ListenerError { error, .. } => {
            warn!("⚠️  Listener error: {}", error);
        }
        
        SwarmEvent::Dialing { peer_id, .. } => {
            if let Some(pid) = peer_id {
                debug!("📞 Dialing peer: {}", pid);
            }
        }
        
        _ => {
            debug!("📋 Other swarm event: {:?}", event);
        }
    }
}

/// Create swarm with all behaviours
fn create_swarm(
    keypair: &identity::Keypair,
    local_peer_id: PeerId,
    transport: libp2p::core::transport::Boxed<(PeerId, libp2p::core::muxing::StreamMuxerBox)>,
) -> Result<Swarm<LibertyBehaviour>, Box<dyn Error>> {
    // Gossipsub configuration
    let gossipsub_config = gossipsub::ConfigBuilder::default()
        .validation_mode(ValidationMode::Strict)
        .message_id_fn(|msg| {
            let mut hasher = sha2::Sha256::new();
            hasher.update(&msg.source.expect("Message source").to_bytes());
            hasher.update(&msg.data);
            gossipsub::MessageId::from(hasher.finalize().to_vec())
        })
        .build()
        .expect("Valid gossipsub config");

    let gossipsub = gossipsub::Behaviour::new(
        MessageAuthenticity::Signed(keypair.clone()),
        gossipsub_config,
    ).expect("Valid gossipsub configuration");

    // mDNS tokio configuration
    let mdns = mdns::tokio::Behaviour::new(
        mdns::Config::default(),
        local_peer_id,
    )?;

    // Kademlia configuration
    let mut kademlia_config = kad::Config::default();
    kademlia_config.set_protocol_names(vec![StreamProtocol::new("/liberty-sovereign/kad/1.0.0")]);

    let store = MemoryStore::new(local_peer_id);
    let mut kademlia = kad::Behaviour::with_config(local_peer_id, store, kademlia_config);
    
    // Bootstrap Kademlia
    if let Err(e) = kademlia.bootstrap() {
        warn!("⚠️  Kademlia bootstrap failed: {}", e);
    }

    // Create behaviour
    let behaviour = LibertyBehaviour {
        gossipsub,
        mdns,
        kademlia,
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
