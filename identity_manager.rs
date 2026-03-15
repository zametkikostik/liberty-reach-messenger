use libp2p::identity;

pub fn load_or_generate_key() -> identity::Keypair {
    // В будущем здесь будет логика чтения из файла
    identity::Keypair::generate_ed25519()
}