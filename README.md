# 🏰 Liberty Reach Messenger

**Decentralized Sovereign Messenger & Financial Freedom Platform**

*Fortress Stable Edition v0.4.0-fortress-stable*

[![Build Status](https://img.shields.io/github/actions/workflow/status/zametkikostik/liberty-reach-messenger/rust.yml)](https://github.com/zametkikostik/liberty-reach-messenger/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange.svg)](https://rust-lang.org)
[![GDPR Compliant](https://img.shields.io/badge/GDPR-compliant-green.svg)](docs/LEGAL_PRIVACY_BG.md)

---

## 🏛️ Mission

**Liberty Reach** — децентрализованная P2P-платформа нового поколения, объединяющая:

- 🕊️ **Свободу связи** — мессенджер без центральных серверов и цензуры
- 💰 **Финансовый суверенитет** — встроенный крипто-агрегатор и Web3-кошелёк
- 🔒 **Приватность по дизайну** — Zero-Knowledge архитектура, E2EE шифрование
- 👨‍👩‍👧 **Семейную безопасность** — система отношений и экстренное отслеживание

> **Мы верим, что технология должна служить свободе человека, а не контролю над ним.**

---

## ✨ Key Features

### 🔐 Security (The Fortress)

| Feature | Description |
|---------|-------------|
| **Post-quantum encryption** | Алгоритм Kyber1024 — защита от квантовых атак |
| **E2EE** | AES-256-GCM + X25519 Key Exchange |
| **Noise Protocol** | Транспортное шифрование (защита от DPI) |
| **Ed25519 signatures** | Криптографическая подпись сообщений |
| **Memory Zeroization** | Мгновенная очистка ключей из памяти |
| **Hardware Binding** | identity.key привязка к устройству |

### 💬 Чаты и общение

- ✅ Приватные чаты 1-на-1 с end-to-end шифрованием
- ✅ Групповые чаты до 1000 участников
- ✅ Каналы для массовых рассылок (broadcast)
- ✅ AI авто-перевод 100+ языков в реальном времени
- ✅ Статусы прочтения и индикаторы набора текста
- ✅ Ответы на сообщения и треды
- ✅ Редактирование и удаление сообщений
- ✅ **24-часовые сообщения** — автоудаление через 24 часа
- ✅ **Таймер самоуничтожения** — удаление через заданное время
- ✅ **Семейные статусы** — женат/замужем/встречаюсь
- ✅ **Синхронизированные обои** — одинаковые у собеседников
- ✅ **Закреплённые сообщения** — важные сообщения в чате
- ✅ **Избранные сообщения** — сохранение с тегами
- ✅ **Отложенные сообщения** — планирование по времени
- ✅ **Стикеры, GIF, Эмодзи реакции**
- ✅ **Ночной режим** — тёмная тема

### 📞 Звонки и конференции

| Тип | Возможности |
|-----|-------------|
| **Аудио звонки** | WebRTC, HD-качество, шумоподавление |
| **Видео звонки** | До 1080p, адаптивный битрейт |
| **AI перевод** | Перевод речи в реальном времени |
| **Субтитры** | WebVTT, 100+ языков |
| **Рация** | Push-to-Talk для быстрой связи |
| **Конференции** | До 100 участников одновременно |

### 🤖 AI функции

- 🧠 **Qwen 3.5 интеграция** — мощный AI-ассистент
- 🌍 **Перевод текста** — 100+ языков
- 📝 **Саммаризация** — краткое содержание чатов
- 💻 **Генерация кода** — помощь разработчикам
- 🎤 **Speech-to-Text** — Vosk, офлайн-распознавание
- 🔊 **Text-to-Speech** — Qwen TTS, естественный голос
- 🎯 **Голосовые команды** — управление без рук

### 💰 Web3 интеграции

- 🦊 **MetaMask** — встроенный кошелёк
- 0️⃣ **0x Protocol** — обмен токенов (0.5-3% комиссия)
- 🔄 **ABCEX API** — покупка криптовалюты (2-3%)
- 📊 **Bitget API** — биржевые операции (2-3%)
- 🤝 **P2P Escrow** — смарт-контракт для безопасных сделок (0.5%)
- 💸 **FeeSplitter** — автоматическое распределение комиссий

### 📲 Миграция

| Источник | Формат | AI перевод |
|----------|--------|------------|
| Telegram | JSON export | ✅ |
| WhatsApp | TXT export | ✅ |

### 📡 P2P сеть

```
┌─────────────────────────────────────────┐
│         DECENTRALIZED NETWORK           │
├─────────────────────────────────────────┤
│ libp2p: TCP, QUIC, Noise, Yamux        │
│ Kademlia DHT для маршрутизации         │
│ Gossipsub для чатов                    │
│ mDNS для локального обнаружения        │
└─────────────────────────────────────────┘
```

---

## 📦 Install

### Требования

```bash
# Rust (обязательно)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Ollama (опционально, для локального AI)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:3b

# Системные зависимости (Ubuntu/Debian)
sudo apt-get install -y libasound2-dev pkg-config libssl-dev
```

### Сборка

```bash
# Клонирование репозитория
git clone https://github.com/zametkikostik/liberty-reach-messenger.git
cd liberty-reach-messenger

# Копирование переменных окружения
cp .env.example .env.local

# Сборка релизной версии
cargo build --release

# Запуск
cargo run --release
```

### Feature Flags

```bash
# Сборка со всеми функциями
cargo build --release

# Сборка без Voice/Calls (не требует аудио-библиотек)
cargo build --release --no-default-features

# Только Voice
cargo build --release --no-default-features --features voice

# Только Groups (без аудио)
cargo build --release --no-default-features
```

---

## 🚀 Deploy to VDS

### Ubuntu 22.04

```bash
# 1. Подготовка сервера
ssh root@your-vds-ip
apt update && apt upgrade -y
apt install -y curl git build-essential pkg-config libssl-dev

# 2. Установка Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# 3. Клонирование
cd /opt
git clone https://github.com/zametkikostik/liberty-reach-messenger.git
cd liberty-reach-messenger
chown -R $USER:$USER /opt/liberty-reach-messenger

# 4. Настройка .env.local
cp .env.example .env.local
nano .env.local

# 5. Сборка
cargo build --release

# 6. systemd сервис
cat > /etc/systemd/system/liberty-reach.service << EOF
[Unit]
Description=Liberty Reach P2P Messenger
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/liberty-reach-messenger
EnvironmentFile=/opt/liberty-reach-messenger/.env.local
ExecStart=/opt/liberty-reach-messenger/target/release/liberty-reach-messenger
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable liberty-reach
systemctl start liberty-reach
systemctl status liberty-reach
```

---

## 🔐 Environment Variables

```bash
# Admin (для Geo-Trace и верификации)
ADMIN_PEER_ID=ваш_peer_id

# AI Integration
OLLAMA_MODEL=qwen2.5-coder:3b
OPENROUTER_API_KEY=sk-or-v1-...

# Storage (Pinata IPFS)
PINATA_API_KEY=your-api-key
PINATA_SECRET_KEY=your-secret-key

# Web3 (Polygon Network)
WEB3_RPC_URL=https://polygon-rpc.com

# Cloudflare Worker (push-уведомления)
CLOUDFLARE_API_KEY=your-cf-api-key
CLOUDFLARE_ACCOUNT_ID=your-cf-account-id

# WebRTC Signaling
SIGNALING_URL=https://secure-messenger-push.kostik.workers.dev
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Liberty Reach                            │
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   P2P Mesh  │  │   E2EE      │  │   AI        │  │ Web3    │ │
│  │   libp2p    │  │   AES-GCM   │  │   Ollama    │  │ Polygon │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Family    │  │   Storage   │  │  Telegram   │  │  WS     │ │
│  │   Safety    │  │   IPFS      │  │   Bridge    │  │ :8080   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
├──────────────────────────────────────────────────────────────────┤
│  GDPR Compliance │ Zero-Knowledge │ Hardware Binding │ Bulgaria │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
liberty-reach-messenger/
├── Cargo.toml              # Зависимости
├── .env.example            # Шаблон переменных
├── README.md               # Документация
├── docs/
│   └── LEGAL_PRIVACY_BG.md # GDPR документ
└── src/
    ├── main.rs             # Ядро
    ├── admin_handlers.rs   # Admin API
    ├── media_handlers.rs   # Media API
    ├── storage_manager.rs  # Storage + GC
    ├── social.rs           # Social Layer
    ├── geo.rs              # Geo Location
    ├── chat_types.rs       # Типы чатов
    ├── ai_guard.rs         # AI модерация
    ├── hybrid_moderation.rs # Модерация
    ├── profiles.rs         # Профили
    ├── stories.rs          # 24h истории
    ├── wallet.rs           # Web3 кошелёк
    ├── hybrid_moderation.rs # AI модерация
    └── ...
```

---

## 🛡️ Security Stack

| Layer | Technology |
|-------|------------|
| **Application** | Double Ratchet + AES-256-GCM |
| **Transport** | Noise Protocol (libp2p-noise) |
| **Network** | libp2p + Kademlia DHT + mDNS |
| **Identity** | Ed25519 Signatures + X25519 DH |
| **Memory** | Zeroize (secure cleanup) |

---

## 🇪🇺 GDPR & Privacy

Liberty Reach разработан в соответствии с:

- **Регламент ЕС 2016/679 (GDPR)** — ст. 5, 6, 25
- **Закон за защита на личните данни (България)** — чл. 1, 3
- **ePrivacy Directive 2002/58/EC** — конфиденциальность

### Zero-Knowledge Architecture

| Принцип | Реализация |
|---------|------------|
| Минимизация данных | Не собираем данные централизованно |
| Хранение на устройстве | Все данные только на устройстве |
| Отсутствие серверов | P2P архитектура |
| Шифрование по умолчанию | E2EE для всех сообщений |
| Право на забвение | Мгновенная очистка (zeroize) |
| Портативность | Экспорт identity.key |

### GDPR Zeroize Endpoint

```bash
# Мгновенное удаление всех данных
curl -X POST http://localhost:3001/api/v1/admin/zeroize \
  -H "X-Peer-ID: ваш_peer_id"
```

---

## 🧪 Testing

```bash
# Все тесты
cargo test

# Тесты с логированием
cargo test -- --nocapture

# Тесты конкретного модуля
cargo test crypto
cargo test identity

# Без voice/calls
cargo test --no-default-features
```

**Результат:** 24 теста пройдено ✅

---

## 📖 Documentation

- [LEGAL_PRIVACY_BG.md](docs/LEGAL_PRIVACY_BG.md) — GDPR & Privacy (BG)
- [API.md](docs/API.md) — API документация
- [SELF_HOSTING.md](docs/SELF_HOSTING.md) — Self-hosting guide

---

## 🤝 Contributing

### Security Guidelines

- ❌ No hardcoded secrets — используйте .env.local
- ✅ Zeroize sensitive data — очищайте ключи из памяти
- ⏱️ Constant-time comparisons — для криптографических операций
- 🔍 Validate all input — не доверяйте внешним данным

### Reporting Vulnerabilities

См. [SECURITY.md](SECURITY.md) для процесса сообщения об уязвимостях.

---

## 📄 License

**MIT License** — Свободное ПО — основа цифрового суверенитета.

---

## 👤 Author

**Konstantin** — Decentralized Systems Developer

- **Email:** intelligent.swallow.aybm@mask.me

---

## 🙏 Acknowledgments

- **libp2p** — децентрализованные сетевые протоколы
- **Ollama** — локальные LLM модели
- **Pinata** — IPFS-хостинг
- **Polygon** — масштабируемый блокчейн
- **Cloudflare** — edge computing и push-уведомления
- **Open Source Community** — криптографические библиотеки

---

## 🚀 GitHub Actions: Автономная сборка APK

**Сборка без VDS — всё через GitHub:**

1. **Actions** → **Hybrid CI/CD Build** → **Run workflow**
2. Параметры: `master_key: REDACTED_PASSWORD` (по умолчанию)
3. Через 5-10 минут: скачай APK из **Artifacts**

🔐 **On-the-Fly Keystore** + **V2/V3 Signing** + **Obfuscation**

📖 **Документация:** [GITHUB_ACTIONS_QUICK_START.md](GITHUB_ACTIONS_QUICK_START.md)

---

## 📞 Contact & Support

- **Email:** intelligent.swallow.aybm@mask.me

---

> **Liberty Reach — потому что свобода связи является фундаментальным правом человека.**

*Built for freedom, encrypted for life.*

**Version:** v0.4.0-fortress-stable  
**Build Date:** 15 марта 2026 г.  
**Security Audit:** Internal ✅
