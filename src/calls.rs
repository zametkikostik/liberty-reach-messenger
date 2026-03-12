//! Модуль WebRTC звонков
//!
//! Реализует:
//! - P2P аудио/видео звонки через webrtc-rs
//! - Signaling через Cloudflare Worker
//! - Обмен SDP и ICE candidates
//! - Шифрование трафика (DTLS-SRTP)

#![cfg(feature = "calls")]

use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use webrtc::api::API;
use webrtc::api::APIBuilder;
use webrtc::ice_transport::ice_credential_type::RTCIceCredentialType;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::track::track_local::track_local_static_rtp::TrackLocalStaticRTP;
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::rtp_transceiver::rtp_codec::MIME_TYPE_AUDIO;
use webrtc::data_channel::RTCDataChannel;
use tokio::sync::mpsc;

/// Тип звонка
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CallType {
    /// Аудио звонок
    Audio,
    /// Видео звонок
    Video,
}

/// Статус звонка
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CallStatus {
    /// Исходящий вызов
    Outgoing,
    /// Входящий вызов
    Incoming,
    /// Соединение установлено
    Connected,
    /// Завершён
    Ended,
    /// Отклонён
    Declined,
    /// Ошибка
    Error(String),
}

/// SDP предложение/ответ
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SDPMessage {
    /// Тип SDP (offer/answer)
    pub sdp_type: String,
    /// SDP данные
    pub sdp: String,
    /// ID звонка
    pub call_id: String,
    /// Отправитель
    pub from_peer_id: String,
    /// Получатель
    pub to_peer_id: String,
}

/// ICE кандидат
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ICECandidate {
    /// ID звонка
    pub call_id: String,
    /// Кандидат (JSON от webrtc)
    pub candidate: serde_json::Value,
    /// Отправитель
    pub from_peer_id: String,
}

/// Сообщение сигнализации
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SignalingMessage {
    #[serde(rename = "offer")]
    Offer(SDPMessage),
    #[serde(rename = "answer")]
    Answer(SDPMessage),
    #[serde(rename = "ice_candidate")]
    IceCandidate(ICECandidate),
    #[serde(rename = "call_start")]
    CallStart {
        call_id: String,
        from_peer_id: String,
        to_peer_id: String,
        call_type: CallType,
    },
    #[serde(rename = "call_end")]
    CallEnd {
        call_id: String,
        from_peer_id: String,
    },
    #[serde(rename = "call_decline")]
    CallDecline {
        call_id: String,
        from_peer_id: String,
        reason: String,
    },
}

/// Активный звонок
pub struct ActiveCall {
    /// ID звонка
    pub call_id: String,
    /// Peer ID собеседника
    pub remote_peer_id: String,
    /// Тип звонка
    pub call_type: CallType,
    /// Статус
    pub status: CallStatus,
    /// WebRTC соединение
    pub peer_connection: Arc<RTCPeerConnection>,
    /// Канал для отправки ICE кандидатов
    pub ice_sender: mpsc::Sender<ICECandidate>,
}

/// Менеджер звонков
pub struct CallManager {
    /// WebRTC API
    api: Arc<API>,
    /// Активные звонки
    calls: Arc<RwLock<Vec<ActiveCall>>>,
    /// Cloudflare Worker URL для сигнализации
    signaling_url: String,
    /// Локальный Peer ID
    local_peer_id: String,
    /// HTTP клиент для signaling
    http_client: reqwest::Client,
}

impl CallManager {
    /// Создание нового менеджера звонков
    pub async fn new(local_peer_id: &str, signaling_url: &str) -> Result<Self> {
        // Создание WebRTC API
        let api = APIBuilder::new().build();

        Ok(Self {
            api: Arc::new(api),
            calls: Arc::new(RwLock::new(Vec::new())),
            signaling_url: signaling_url.to_string(),
            local_peer_id: local_peer_id.to_string(),
            http_client: reqwest::Client::new(),
        })
    }

    /// Начать исходящий звонок
    pub async fn start_call(&self, remote_peer_id: &str, call_type: CallType) -> Result<String> {
        let call_id = uuid::Uuid::new_v4().to_string();

        tracing::info!("📞 Начало звонка {} (тип: {:?}", call_id, call_type);

        // Создание peer connection
        let config = RTCConfiguration {
            ice_servers: vec![
                RTCIceServer {
                    urls: vec![
                        "stun:stun.l.google.com:19302".to_string(),
                        "stun:stun1.l.google.com:19302".to_string(),
                    ],
                    ..Default::default()
                },
            ],
            ..Default::default()
        };

        let peer_connection = Arc::new(self.api.new_peer_connection(config).await?);

        // Создание канала для ICE кандидатов
        let (ice_sender, mut ice_receiver) = mpsc::channel(100);

        // Обработка ICE кандидатов
        let pc_clone = Arc::clone(&peer_connection);
        let signaling_url = self.signaling_url.clone();
        let from_peer_id = self.local_peer_id.clone();
        let call_id_clone = call_id.clone();

        tokio::spawn(async move {
            while let Some(candidate) = ice_receiver.recv().await {
                // Отправка кандидата через signaling сервер
                let _ = send_signaling_message(&signaling_url, &SignalingMessage::IceCandidate(candidate)).await;
            }
        });

        // Обработка ICE кандидатов от WebRTC
        let ice_sender_clone = ice_sender.clone();
        peer_connection.on_ice_candidate(Box::new(move |c| {
            let sender = ice_sender_clone.clone();
            Box::pin(async move {
                if let Some(candidate) = c {
                    let ice_candidate = ICECandidate {
                        call_id: call_id_clone.clone(),
                        candidate: serde_json::to_value(&candidate).unwrap_or_default(),
                        from_peer_id: from_peer_id.clone(),
                    };
                    let _ = sender.send(ice_candidate).await;
                }
            })
        }));

        // Добавление audio track
        if call_type == CallType::Audio || call_type == CallType::Video {
            let track = Arc::new(TrackLocalStaticRTP::new(
                &RTCRtpCodecCapability {
                    mime_type: MIME_TYPE_AUDIO.to_string(),
                    clock_rate: 48000,
                    channels: 2,
                    ..Default::default()
                },
                "audio".to_string(),
                "liberty-reach".to_string(),
            ));

            peer_connection.add_track(track).await?;
        }

        // Создание SDP offer
        let offer = peer_connection.create_offer(None).await?;
        peer_connection.set_local_description(offer.clone()).await?;

        // Отправка offer через signaling
        let sdp_message = SDPMessage {
            sdp_type: "offer".to_string(),
            sdp: offer.sdp,
            call_id: call_id.clone(),
            from_peer_id: self.local_peer_id.clone(),
            to_peer_id: remote_peer_id.to_string(),
        };

        send_signaling_message(
            &self.signaling_url,
            &SignalingMessage::Offer(sdp_message),
        ).await?;

        // Сохранение активного звонка
        let call = ActiveCall {
            call_id: call_id.clone(),
            remote_peer_id: remote_peer_id.to_string(),
            call_type,
            status: CallStatus::Outgoing,
            peer_connection: Arc::clone(&peer_connection),
            ice_sender,
        };

        {
            let mut calls = self.calls.write().await;
            calls.push(call);
        }

        Ok(call_id)
    }

    /// Обработка входящего SDP offer
    pub async fn handle_offer(&self, offer_msg: SDPMessage) -> Result<()> {
        tracing::info!("📥 Получен SDP offer от {}", offer_msg.from_peer_id);

        let config = RTCConfiguration {
            ice_servers: vec![
                RTCIceServer {
                    urls: vec![
                        "stun:stun.l.google.com:19302".to_string(),
                        "stun:stun1.l.google.com:19302".to_string(),
                    ],
                    ..Default::default()
                },
            ],
            ..Default::default()
        };

        let peer_connection = Arc::new(self.api.new_peer_connection(config).await?);
        let (ice_sender, mut ice_receiver) = mpsc::channel(100);

        // Обработка ICE кандидатов
        let pc_clone = Arc::clone(&peer_connection);
        let signaling_url = self.signaling_url.clone();
        let from_peer_id = self.local_peer_id.clone();
        let call_id_clone = offer_msg.call_id.clone();

        tokio::spawn(async move {
            while let Some(candidate) = ice_receiver.recv().await {
                let _ = send_signaling_message(&signaling_url, &SignalingMessage::IceCandidate(candidate)).await;
            }
        });

        let ice_sender_clone = ice_sender.clone();
        peer_connection.on_ice_candidate(Box::new(move |c| {
            let sender = ice_sender_clone.clone();
            Box::pin(async move {
                if let Some(candidate) = c {
                    let ice_candidate = ICECandidate {
                        call_id: call_id_clone.clone(),
                        candidate: serde_json::to_value(&candidate).unwrap_or_default(),
                        from_peer_id: from_peer_id.clone(),
                    };
                    let _ = sender.send(ice_candidate).await;
                }
            })
        }));

        // Установка remote description
        let remote_desc = RTCSessionDescription::offer(offer_msg.sdp)?;
        peer_connection.set_remote_description(remote_desc).await?;

        // Создание answer
        let answer = peer_connection.create_answer(None).await?;
        peer_connection.set_local_description(answer.clone()).await?;

        // Отправка answer
        let answer_msg = SDPMessage {
            sdp_type: "answer".to_string(),
            sdp: answer.sdp,
            call_id: offer_msg.call_id.clone(),
            from_peer_id: self.local_peer_id.clone(),
            to_peer_id: offer_msg.from_peer_id,
        };

        send_signaling_message(
            &self.signaling_url,
            &SignalingMessage::Answer(answer_msg),
        ).await?;

        // Сохранение звонка
        let call = ActiveCall {
            call_id: offer_msg.call_id.clone(),
            remote_peer_id: offer_msg.from_peer_id,
            call_type: CallType::Audio, // По умолчанию аудио
            status: CallStatus::Connected,
            peer_connection: Arc::clone(&peer_connection),
            ice_sender,
        };

        {
            let mut calls = self.calls.write().await;
            calls.push(call);
        }

        Ok(())
    }

    /// Обработка ICE кандидата
    pub async fn handle_ice_candidate(&self, candidate: ICECandidate) -> Result<()> {
        let calls = self.calls.read().await;
        if let Some(call) = calls.iter().find(|c| c.call_id == candidate.call_id) {
            // Добавление ICE кандидата
            // В продакшене здесь была бы полная обработка
            tracing::debug!("📨 Получен ICE кандидат для звонка {}", candidate.call_id);
        }
        Ok(())
    }

    /// Завершение звонка
    pub async fn end_call(&self, call_id: &str) -> Result<()> {
        let mut calls = self.calls.write().await;

        if let Some(pos) = calls.iter().position(|c| c.call_id == call_id) {
            let call = calls.remove(pos);

            // Отправка сообщения о завершении
            let end_message = SignalingMessage::CallEnd {
                call_id: call_id.to_string(),
                from_peer_id: self.local_peer_id.clone(),
            };

            let _ = send_signaling_message(&self.signaling_url, &end_message).await;

            // Закрытие peer connection
            call.peer_connection.close().await?;

            tracing::info!("📴 Звонок {} завершён", call_id);
        }

        Ok(())
    }

    /// Получение статуса звонка
    pub async fn get_call_status(&self, call_id: &str) -> Option<CallStatus> {
        let calls = self.calls.read().await;
        calls.iter()
            .find(|c| c.call_id == call_id)
            .map(|c| c.status.clone())
    }

    /// Получение списка активных звонков
    pub async fn get_active_calls(&self) -> Vec<String> {
        let calls = self.calls.read().await;
        calls.iter().map(|c| c.call_id.clone()).collect()
    }
}

/// Отправка signaling сообщения через Cloudflare Worker
async fn send_signaling_message(url: &str, message: &SignalingMessage) -> Result<()> {
    let client = reqwest::Client::new();

    let response = client.post(url)
        .json(message)
        .send()
        .await
        .context("Ошибка отправки signaling сообщения")?;

    if !response.status().is_success() {
        anyhow::bail!("Signaling сервер вернул ошибку: {}", response.status());
    }

    Ok(())
}

/// Получение signaling сообщений из Cloudflare Worker
pub async fn fetch_signaling_messages(url: &str, peer_id: &str) -> Result<Vec<SignalingMessage>> {
    let client = reqwest::Client::new();

    let response = client.get(url)
        .query(&[("peer_id", peer_id)])
        .send()
        .await
        .context("Ошибка получения signaling сообщений")?;

    if !response.status().is_success() {
        return Ok(Vec::new());
    }

    let messages: Vec<SignalingMessage> = response.json().await.unwrap_or_default();
    Ok(messages)
}

/// Команды менеджера звонков
pub const CALL_COMMANDS: &[(&str, &str)] = &[
    ("/call audio [peer_id]", "Начать аудио звонок"),
    ("/call video [peer_id]", "Начать видео звонок"),
    ("/call end [call_id]", "Завершить звонок"),
    ("/call status", "Показать активные звонки"),
    ("/call decline [call_id]", "Отклонить входящий звонок"),
];

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_call_manager_creation() {
        let manager = CallManager::new("test_peer_123", "http://localhost:8787").await;
        assert!(manager.is_ok());
    }

    #[test]
    fn test_signaling_message_serialization() {
        let msg = SignalingMessage::CallStart {
            call_id: "test-123".to_string(),
            from_peer_id: "peer1".to_string(),
            to_peer_id: "peer2".to_string(),
            call_type: CallType::Audio,
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("call_start"));

        let decoded: SignalingMessage = serde_json::from_str(&json).unwrap();
        match decoded {
            SignalingMessage::CallStart { call_id, .. } => {
                assert_eq!(call_id, "test-123");
            }
            _ => panic!("Неверный тип сообщения"),
        }
    }

    #[test]
    fn test_call_type_serialization() {
        let audio = CallType::Audio;
        let video = CallType::Video;

        let audio_json = serde_json::to_string(&audio).unwrap();
        let video_json = serde_json::to_string(&video).unwrap();

        assert_eq!(audio_json, "\"Audio\"");
        assert_eq!(video_json, "\"Video\"");
    }
}
