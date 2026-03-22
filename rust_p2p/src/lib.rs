//! Liberty P2P - Минимальная версия для общения без блокировок

use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Identity {
    pub peer_id: String,
    pub public_key: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Peer {
    pub peer_id: String,
    pub address: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub from: String,
    pub content: String,
    pub timestamp: u64,
    pub encrypted: bool,
}

pub struct P2PNode {
    identity: Identity,
}

impl P2PNode {
    pub fn new() -> Self {
        Self {
            identity: Identity {
                peer_id: format!("peer_{}", uuid::Uuid::new_v4()),
                public_key: "pubkey".to_string(),
            },
        }
    }
    
    pub fn start(&self) -> String {
        self.identity.peer_id.clone()
    }
    
    pub fn get_peers(&self) -> Vec<Peer> {
        vec![]
    }
    
    pub fn send_message(&self, content: &str) -> Message {
        Message {
            id: uuid::Uuid::new_v4().to_string(),
            from: self.identity.peer_id.clone(),
            content: content.to_string(),
            timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
            encrypted: true,
        }
    }
}

// FFI ДЛЯ ANDROID
#[no_mangle]
pub extern "C" fn create_identity() -> *mut libc::c_char {
    let node = P2PNode::new();
    let json = serde_json::to_string(&node.identity).unwrap_or_default();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn start_node() -> *mut libc::c_char {
    let node = P2PNode::new();
    let peer_id = node.start();
    let json = serde_json::to_string(&Identity { 
        peer_id, 
        public_key: "key".to_string() 
    }).unwrap_or_default();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn get_peers() -> *mut libc::c_char {
    let peers: Vec<Peer> = vec![];
    let json = serde_json::to_string(&peers).unwrap_or_default();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn send_message(content: *const libc::c_char) -> *mut libc::c_char {
    let content_str = unsafe { std::ffi::CStr::from_ptr(content) }
        .to_string_lossy()
        .into_owned();
    
    let node = P2PNode::new();
    let msg = node.send_message(&content_str);
    let json = serde_json::to_string(&msg).unwrap_or_default();
    std::ffi::CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn free_string(s: *mut libc::c_char) {
    unsafe {
        if !s.is_null() {
            let _ = std::ffi::CString::from_raw(s);
        }
    }
}
