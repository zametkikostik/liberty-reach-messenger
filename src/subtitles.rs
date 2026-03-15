//! Subtitles Module for Audio/Video Calls
//!
//! Функции:
//! - Speech-to-Text для аудио/видео звонков
//! - Генерация субтитров в реальном времени
//! - Перевод субтитров на лету
//! - WebVTT формат

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::translator::{Language, TranslationManager, TranslatedMessage};

/// Субтитр (одна реплика)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Subtitle {
    /// Начало реплики (мс)
    pub start_ms: u64,
    /// Конец реплики (мс)
    pub end_ms: u64,
    /// Текст оригинала
    pub text: String,
    /// Переведённый текст
    pub translated_text: Option<String>,
    /// Язык оригинала
    pub language: Language,
    /// Временная метка
    pub timestamp: DateTime<Utc>,
    /// PeerID говорящего
    pub speaker_peer_id: Option<String>,
}

impl Subtitle {
    pub fn new(start_ms: u64, end_ms: u64, text: String, language: Language) -> Self {
        Self {
            start_ms,
            end_ms,
            text,
            translated_text: None,
            language,
            timestamp: Utc::now(),
            speaker_peer_id: None,
        }
    }

    pub fn with_translation(mut self, translated: String) -> Self {
        self.translated_text = Some(translated);
        self
    }

    pub fn with_speaker(mut self, peer_id: String) -> Self {
        self.speaker_peer_id = Some(peer_id);
        self
    }

    /// Длительность реплики в мс
    pub fn duration_ms(&self) -> u64 {
        self.end_ms - self.start_ms
    }

    /// Конвертация в WebVTT формат
    pub fn to_webvtt(&self) -> String {
        let start = Self::ms_to_webvtt_time(self.start_ms);
        let end = Self::ms_to_webvtt_time(self.end_ms);
        
        let text = if let Some(ref translated) = self.translated_text {
            format!("{}\n{}", self.text, translated)
        } else {
            self.text.clone()
        };

        format!("{} --> {}\n{}\n\n", start, end, text)
    }

    fn ms_to_webvtt_time(ms: u64) -> String {
        let hours = ms / 3600000;
        let minutes = (ms % 3600000) / 60000;
        let seconds = (ms % 60000) / 1000;
        let milliseconds = ms % 1000;

        format!("{:02}:{:02}:{:02}.{:03}", hours, minutes, seconds, milliseconds)
    }
}

/// Сессия субтитров (для звонка)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubtitleSession {
    /// ID сессии (ID звонка)
    pub session_id: String,
    /// Список субтитров
    pub subtitles: Vec<Subtitle>,
    /// Начальное время сессии
    pub started_at: DateTime<Utc>,
    /// Завершено ли
    pub is_active: bool,
    /// Язык перевода
    pub target_language: Language,
}

impl SubtitleSession {
    pub fn new(session_id: String, target_language: Language) -> Self {
        Self {
            session_id,
            subtitles: Vec::new(),
            started_at: Utc::now(),
            is_active: true,
            target_language,
        }
    }

    pub fn add_subtitle(&mut self, subtitle: Subtitle) {
        self.subtitles.push(subtitle);
    }

    pub fn finish(&mut self) {
        self.is_active = false;
    }

    /// Экспорт в WebVTT файл
    pub fn export_webvtt(&self) -> String {
        let mut webvtt = String::from("WEBVTT\n\n");

        for subtitle in &self.subtitles {
            webvtt.push_str(&subtitle.to_webvtt());
        }

        webvtt
    }

    /// Получить последние N субтитров
    pub fn get_recent(&self, count: usize) -> Vec<Subtitle> {
        self.subtitles
            .iter()
            .rev()
            .take(count)
            .cloned()
            .collect()
    }
}

/// Менеджер субтитров
pub struct SubtitleManager {
    /// Активные сессии
    sessions: Arc<RwLock<HashMap<String, SubtitleSession>>>,
    /// Менеджер переводов
    translation_manager: Arc<TranslationManager>,
    /// Буфер для потокового STT
    stt_buffer: Arc<RwLock<HashMap<String, Vec<u8>>>>,
}

use std::collections::HashMap;

impl SubtitleManager {
    pub fn new(translation_manager: Arc<TranslationManager>) -> Self {
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
            translation_manager,
            stt_buffer: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Начать новую сессию субтитров
    pub async fn start_session(
        &self,
        session_id: &str,
        target_language: Language,
    ) {
        let mut sessions = self.sessions.write().await;
        sessions.insert(
            session_id.to_string(),
            SubtitleSession::new(session_id.to_string(), target_language),
        );
    }

    /// Добавить субтитр в сессию
    pub async fn add_subtitle(
        &self,
        session_id: &str,
        start_ms: u64,
        end_ms: u64,
        text: String,
        language: Language,
        speaker_peer_id: Option<String>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut sessions = self.sessions.write().await;
        
        if let Some(session) = sessions.get_mut(session_id) {
            let mut subtitle = Subtitle::new(start_ms, end_ms, text, language);
            
            if let Some(peer_id) = speaker_peer_id {
                subtitle = subtitle.with_speaker(peer_id);
            }

            // Перевод если включён
            if session.target_language != language {
                if let Ok(translated) = self
                    .translation_manager
                    .translate(&subtitle.text, language, session.target_language)
                    .await
                {
                    subtitle = subtitle.with_translation(translated.translated_text);
                }
            }

            session.add_subtitle(subtitle);
        }

        Ok(())
    }

    /// Завершить сессию
    pub async fn end_session(&self, session_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut sessions = self.sessions.write().await;
        
        if let Some(session) = sessions.get_mut(session_id) {
            session.finish();
        }

        Ok(())
    }

    /// Получить сессию
    pub async fn get_session(&self, session_id: &str) -> Option<SubtitleSession> {
        let sessions = self.sessions.read().await;
        sessions.get(session_id).cloned()
    }

    /// Получить активные сессии
    pub async fn get_active_sessions(&self) -> Vec<String> {
        let sessions = self.sessions.read().await;
        sessions
            .iter()
            .filter(|(_, s)| s.is_active)
            .map(|(id, _)| id.clone())
            .collect()
    }

    /// Экспорт сессии в WebVTT
    pub async fn export_session_webvtt(&self, session_id: &str) -> Option<String> {
        let sessions = self.sessions.read().await;
        sessions.get(session_id).map(|s| s.export_webvtt())
    }

    /// Обработка аудио потока (STT)
    pub async fn process_audio_stream(
        &self,
        session_id: &str,
        audio_data: &[u8],
    ) -> Result<Option<Subtitle>, Box<dyn std::error::Error>> {
        // Добавление в буфер
        let mut buffer = self.stt_buffer.write().await;
        buffer.entry(session_id.to_string()).or_insert_with(Vec::new).extend_from_slice(audio_data);

        // TODO: Интеграция с Vosk STT для распознавания речи
        // Пример: когда буфер достигает определённого размера

        // Заглушка для демонстрации
        Ok(None)
    }

    /// Очистить буфер STT
    pub async fn clear_stt_buffer(&self, session_id: &str) {
        let mut buffer = self.stt_buffer.write().await;
        buffer.remove(session_id);
    }

    /// Получить статистику
    pub async fn get_stats(&self) -> SubtitleStats {
        let sessions = self.sessions.read().await;
        let active = sessions.values().filter(|s| s.is_active).count();
        let total_subtitles: usize = sessions.values().map(|s| s.subtitles.len()).sum();

        SubtitleStats {
            active_sessions: active,
            total_sessions: sessions.len(),
            total_subtitles,
        }
    }
}

/// Статистика субтитров
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubtitleStats {
    pub active_sessions: usize,
    pub total_sessions: usize,
    pub total_subtitles: usize,
}

/// API Request/Response структуры
#[derive(Debug, Serialize, Deserialize)]
pub struct StartSubtitleSessionRequest {
    pub session_id: String,
    pub target_language: Language,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AddSubtitleRequest {
    pub session_id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
    pub language: Language,
    pub speaker_peer_id: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ExportSubtitleResponse {
    pub session_id: String,
    pub format: String, // webvtt
    pub content: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_subtitle_webvtt() {
        let subtitle = Subtitle::new(
            1000,
            5000,
            "Hello, World!".to_string(),
            Language::English,
        );

        let webvtt = subtitle.to_webvtt();
        assert!(webvtt.contains("00:00:01.000 --> 00:00:05.000"));
        assert!(webvtt.contains("Hello, World!"));
    }

    #[tokio::test]
    async fn test_subtitle_session() {
        let mut session = SubtitleSession::new("call_123".to_string(), Language::Bulgarian);
        
        session.add_subtitle(Subtitle::new(
            0,
            3000,
            "Привет".to_string(),
            Language::Russian,
        ));
        
        session.add_subtitle(Subtitle::new(
            3500,
            7000,
            "Как дела?".to_string(),
            Language::Russian,
        ));

        let webvtt = session.export_webvtt();
        assert!(webvtt.starts_with("WEBVTT"));
        assert_eq!(session.subtitles.len(), 2);
    }
}
