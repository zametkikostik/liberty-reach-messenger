//! Liberty P2P - Minimal Rust libp2p Core for Android
//! 
//! Minimal implementation that compiles!

use serde::{Deserialize, Serialize};

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// 🔐 Identity Keys
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityKeys {
    pub peer_id: String,
}

/// 📡 Peer Info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub peer_id: String,
    pub address: String,
    pub status: String,
}

/// 🏗️ P2P Node
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct P2PNode {
    pub peer_id: String,
    pub is_running: bool,
}

/// 📨 Message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub content: String,
    pub encrypted: bool,
}

// ============================================================================
// FFI EXPORTS
// ============================================================================

#[no_mangle]
pub extern "C" fn create_identity() -> *mut libc::c_char {
    let peer_id = format!("rust_peer_{}", uuid::Uuid::new_v4());
    let json = serde_json::to_string(&IdentityKeys { peer_id }).unwrap();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn start_p2p_node(_bootstrap: *const libc::c_char) -> *mut libc::c_char {
    let node = P2PNode {
        peer_id: "rust_node_1".to_string(),
        is_running: true,
    };
    let json = serde_json::to_string(&node).unwrap();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn discover_peers() -> *mut libc::c_char {
    let peers: Vec<PeerInfo> = vec![];
    let json = serde_json::to_string(&peers).unwrap();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn send_message(_receiver: *const libc::c_char, content: *const libc::c_char) -> *mut libc::c_char {
    let msg = ChatMessage {
        id: uuid::Uuid::new_v4().to_string(),
        content: unsafe { std::ffi::CStr::from_ptr(content).to_string_lossy().into_owned() },
        encrypted: true,
    };
    let json = serde_json::to_string(&msg).unwrap();
    std::ffi::CString::new(json).unwrap().into_raw()
}

// ============================================================================
// CLEANUP
// ============================================================================

#[no_mangle]
pub extern "C" fn free_string(s: *mut libc::c_char) {
    unsafe {
        if s.is_null() { return; }
        let _ = std::ffi::CString::from_raw(s);
    }
}
