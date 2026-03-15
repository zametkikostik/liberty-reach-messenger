use libp2p::{mdns, gossipsub, swarm::NetworkBehaviour, PeerId};

#[derive(NetworkBehaviour)]
#[behaviour(out_event = "MyBehaviourEvent")]
pub struct MyBehaviour {
    pub mdns: mdns::tokio::Behaviour,
    pub gossipsub: gossipsub::Behaviour,
}

#[derive(Debug)]
pub enum MyBehaviourEvent {
    Mdns(mdns::Event),
    Gossipsub(gossipsub::Event),
}

impl From<mdns::Event> for MyBehaviourEvent {
    fn from(event: mdns::Event) -> Self {
        MyBehaviourEvent::Mdns(event)
    }
}

impl From<gossipsub::Event> for MyBehaviourEvent {
    fn from(event: gossipsub::Event) -> Self {
        MyBehaviourEvent::Gossipsub(event)
    }
}

impl MyBehaviour {
    pub fn new(local_peer_id: PeerId, gossipsub: gossipsub::Behaviour) -> Self {
        let mdns = mdns::tokio::Behaviour::new(
            mdns::Config::default(),
            local_peer_id
        ).expect("Ошибка mDNS");

        Self { mdns, gossipsub }
    }
}
