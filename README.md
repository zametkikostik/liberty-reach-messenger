# Liberty Reach

**Decentralized Sovereign Messenger & Financial Freedom Platform**

> *Fortress Stable Edition v0.4.0-fortress-stable*

---

## 🏛️ Mission

Liberty Reach — это децентрализованная P2P-платформа нового поколения, объединяющая:

- **Свободу связи** — мессенджер без центральных серверов и цензуры
- **Финансовый суверенитет** — встроенный крипто-агрегатор и Web3-кошелёк
- **Приватность по дизайну** — Zero-Knowledge архитектура, E2EE шифрование
- **Семейную безопасность** — система отношений и экстренное отслеживание

Мы верим, что технология должна служить свободе человека, а не контролю над ним.

---

## ✨ Features

### P2P Mesh Network
- **libp2p** — децентрализованная сеть без единой точки отказа
- **GossipSub** — эффективная рассылка сообщений в реальном времени
- **Kademlia DHT** — распределённая маршрутизация и обнаружение узлов
- **AutoNAT + Relay** — обход NAT, работа за фаерволами
- **mDNS** — локальное обнаружение в LAN

### End-to-End Encryption (E2EE)
- **AES-256-GCM** — authenticated encryption с тегами целостности
- **X25519 Diffie-Hellman** — обмен ключами через эллиптические кривые
- **Ephemeral Keys** — одноразовые секреты с немедленной нулизацией
- **Perfect Forward Secrecy** — компрометация ключа не раскрывает историю

### AI Integration
- **Ollama** — локальные LLM (qwen2.5-coder, llama3, mistral)
- **OpenRouter** — доступ к облачным моделям (GPT-4, Claude, Gemini)
- **Контекстный анализ** — AI отвечает с учётом истории чата
- **Приватность** — запросы к локальному AI не покидают устройство

### Crypto-Exchange Aggregator
- **0.5% Liquidity Protocol** — агрегация ликвидности с минимальной комиссией
- **Multi-DEX** — поддержка Uniswap, SushiSwap, Curve, Balancer
- **Polygon Network** — низкие комиссии, высокая скорость транзакций
- **Токены**: MATIC, USDC, USDT, DAI, любые ERC-20
- **Web3 Wallet** — встроенный кошелёк с просмотром баланса

### Stories 24h (IPFS)
- **Pinata IPFS** — децентрализованное хранение медиа
- **24-часовое время жизни** — автоматическое удаление старых историй
- **CID-ссылки** — контентно-адресуемое хранилище
- **Метаданные** — JSON-описания с временными метками

### Dynamic Themes
- **Адаптивный UI** — светлая/тёмная тема
- **Семейные статусы** — визуальные индикаторы отношений
- **Персонализация** — настройка под предпочтения пользователя

### 🎤 Voice Messages (NEW)
- **cpal** — захват звука с микрофона
- **Opus codec** — эффективное сжатие аудио
- **E2EE** — шифрование AES-256-GCM перед отправкой
- **IPFS/Pinata** — децентрализованное хранение
- **Команды**: `/voice_start`, `/voice_stop`, `/voice_play`

### 📞 WebRTC Calls (NEW)
- **webrtc-rs** — P2P аудио/видео звонки
- **Signaling** — через Cloudflare Worker
- **DTLS-SRTP** — шифрование медиа трафика
- **STUN/TURN** — обход NAT и фаерволов
- **Команды**: `/call audio`, `/call video`, `/call end`

### 👥 Group Chats (NEW)
- **Динамические топики** — `liberty-group-[ID]` в Gossipsub
- **Роли** — Owner, Admin, Moderator, Member
- **Групповое шифрование** — общий ключ для участников
- **Права доступа** — приглашение, кик, настройки
- **Команды**: `/group create`, `/group join`, `/group invite`

---

## 🏰 Security (The Fortress)

### Hardware Binding
- **identity.key** — привязка к аппаратному идентификатору устройства
- **Права доступа 600** — только владелец может читать ключ (Unix)
- **Secure Enclave** — поддержка аппаратных хранилищ ключей (TPM, Secure Element)

### Memory Zeroization
- **EphemeralSecret** — секретные ключи уничтожаются после использования
- **ZeroOnDrop** — автоматическая очистка памяти при выходе из области видимости
- **No Swap** — предотвращение выгрузки чувствительных данных в swap-раздел

### Stealth Mode
- **Маскировка трафика** — обфускация P2P-соединений
- **Отсутствие метаданных** — никакая информация о контактах не сохраняется
- **Anti-Fingerprinting** — защита от идентификации по отпечатку браузера/устройства

### Anti-Brute Force
- **Rate Limiting** — ограничение количества попыток аутентификации
- **Exponential Backoff** — задержка увеличивается после каждой неудачной попытки
- **Account Lockout** — временная блокировка при подозрительной активности

---

## 🇪🇺 GDPR & Privacy by Design

### Соответствие законодательству ЕС и Болгарии

Liberty Reach разработан в соответствии с:
- **GDPR (General Data Protection Regulation)** — Регламент ЕС 2016/679
- **Закон о защите персональных данных Республики Болгария**
- **ePrivacy Directive** — директива о конфиденциальности в электронных коммуникациях

### Zero-Knowledge Architecture

| Принцип | Реализация |
|---------|------------|
| **Минимизация данных** | Мессенджер не собирает персональные данные на центральных серверах |
| **Хранение на устройстве** | Все сообщения, контакты и медиа хранятся только на устройствах пользователей |
| **Отсутствие серверов** | Децентрализованная P2P-архитектура исключает единый центр сбора данных |
| **Шифрование по умолчанию** | E2EE обеспечивает недоступность данных для третьих лиц |
| **Право на забвение** | Пользователь может удалить все данные мгновенно (уничтожение ключей) |
| **Портативность данных** | Экспорт идентичности через identity.key (перенос на новое устройство) |

### Категории данных (не собираются)

- ❌ Телефонные номера
- ❌ Email-адреса
- ❌ Геолокация (без явного согласия для Family Safety)
- ❌ Метаданные сообщений (кто, кому, когда)
- ❌ История переписки на серверах
- ❌ IP-адреса (маршрутизация через P2P mesh)

### Правовое основание

Поскольку Liberty Reach не обрабатывает персональные данные централизованно, проект не требует назначения Data Protection Officer (DPO) и регистрации в реестрах обработчиков данных.

---

## 👨‍👩‍👧 Family Safety & Geo-Discovery

### Экстренное отслеживание близких

Liberty Reach включает функцию **Family Safety** для поиска членов семьи в экстренных ситуациях:

- **Доверенный круг** — только подтверждённые контакты со статусом `Family` или `Partner`
- **Geo-Discovery** — обмен геопозицией по запросу (требуется явное согласие)
- **SOS-сигнал** — экстренная рассылка местоположения доверенным контактам
- **История перемещений** — не сохраняется, только текущая позиция в реальном времени
- **Отключение в один клик** — пользователь может прекратить доступ в любой момент

### Сценарии использования

1. **Ребёнок потерялся** — родитель видит местоположение на карте
2. **Пожилой родственник** — помощь при дезориентации
3. **Экстренная ситуация** — быстрая координация помощи
4. **Путешествия** — проверка безопасности близких в пути

> ⚠️ **Важно**: Функция требует двустороннего подтверждения. Невозможно отслеживать человека без его согласия.

---

## 📦 Install

### Требования

```bash
# Rust (обязательно)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Ollama (опционально, для локального AI)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:3b

# Node.js (для Cloudflare Worker)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts
```

### Сборка мессенджера (Rust + Cargo)

```bash
# Клонирование репозитория
git clone <repository-url>
cd liberty-reach-messenger

# Копирование шаблона переменных окружения
cp .env.local.example .env.local

# Редактирование .env.local (добавьте ваши API-ключи)
nano .env.local

# Сборка релизной версии
cargo build --release

# Запуск
cargo run

# Запуск с логированием
RUST_LOG=liberty_reach_messenger=debug cargo run
```

### Деплой Cloudflare Worker (Push-уведомления)

```bash
# Перейдите в директорию Worker
cd /home/kostik/cloudflare-secure-messenger

# Установка wrangler (CLI Cloudflare)
npm install -g wrangler

# Авторизация в Cloudflare
wrangler login

# Деплой Worker
wrangler deploy

# Проверка
curl https://secure-messenger-push.kostik.workers.dev/
```

**Ручной деплой через Dashboard:**

1. Откройте https://dash.cloudflare.com/
2. Workers & Pages → secure-messenger-push → Edit Code
3. Вставьте код из `/src/worker.js`
4. Settings → Bindings → Add KV Namespace → `PUSH_STORE`
5. Save and Deploy

---

## 🚀 Deploy to VDS (Ubuntu 22.04)

### Шаг 1: Подготовка сервера

```bash
# Подключение к серверу
ssh root@your-vds-ip

# Обновление системы
apt update && apt upgrade -y

# Установка необходимых пакетов
apt install -y curl git build-essential pkg-config libssl-dev
```

### Шаг 2: Установка Rust

```bash
# Установка Rust через rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Загрузка переменных окружения
source $HOME/.cargo/env

# Проверка установки
rustc --version
cargo --version
```

### Шаг 3: Клонирование репозитория

```bash
# Клонирование репозитория
cd /opt
git clone https://github.com/zametkikostik/liberty-reach-messenger.git
cd liberty-reach-messenger

# Установка прав
chown -R $USER:$USER /opt/liberty-reach-messenger
chmod 700 /opt/liberty-reach-messenger
```

### Шаг 4: Настройка переменных окружения

```bash
# Копирование шаблона
cp .env.local.example .env.local

# Редактирование переменных
nano .env.local
```

**Необходимые переменные:**

```bash
# Admin (для Geo-Trace и верификации)
ADMIN_EMAIL=zametkikostik@gmail.com
ADMIN_PEER_ID_HASH=<сгенерируйте через: echo -n "ваш-peer-id" | sha256sum>

# AI (опционально)
OLLAMA_MODEL=qwen2.5-coder:3b
# или
OPENROUTER_API_KEY=sk-or-v1-...

# Storage (опционально)
PINATA_API_KEY=your-pinata-key
PINATA_SECRET_KEY=your-pinata-secret

# Web3 (опционально)
WEB3_RPC_URL=https://polygon-rpc.com

# Telegram Bridge (опционально)
TELEGRAM_BOT_TOKEN=your-bot-token

# Cloudflare KV (для push-уведомлений и signaling)
CLOUDFLARE_API_KEY=your-cf-api-key
CLOUDFLARE_ACCOUNT_ID=your-cf-account-id
KV_NAMESPACE_ID=your-kv-namespace-id

# WebRTC Signaling (опционально)
SIGNALING_URL=https://secure-messenger-push.kostik.workers.dev
```

### Шаг 5.5: Сборка с Feature Flags

```bash
# Сборка со всеми функциями (требует libasound2-dev)
cargo build --release

# Сборка без Voice/Calls (не требует аудио-библиотек)
cargo build --release --no-default-features

# Сборка только с Voice
cargo build --release --no-default-features --features voice

# Сборка только с Calls
cargo build --release --no-default-features --features calls

# Сборка только с Groups (без аудио)
cargo build --release --no-default-features
```

**Системные зависимости для Voice/Calls:**

```bash
# Ubuntu/Debian
sudo apt-get install -y libasound2-dev pkg-config

# Fedora/RHEL
sudo dnf install -y alsa-lib-devel pkg-config
```

### Шаг 6: Сборка релизной версии

```bash
# Сборка оптимизированной версии
cargo build --release

# Проверка сборки
./target/release/liberty-reach-messenger --help
```

### Шаг 7: Создание systemd сервиса

```bash
# Создание файла сервиса
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
StandardOutput=journal
StandardError=journal
SyslogIdentifier=liberty-reach

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/liberty-reach-messenger

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd
systemctl daemon-reload

# Включение автозапуска
systemctl enable liberty-reach

# Запуск сервиса
systemctl start liberty-reach

# Проверка статуса
systemctl status liberty-reach

# Просмотр логов
journalctl -u liberty-reach -f
```

### Шаг 8: Настройка брандмауэра (UFW)

```bash
# Установка UFW
apt install -y ufw

# Разрешение SSH
ufw allow 22/tcp

# Разрешение WebSocket (для веб-фронтенда)
ufw allow 8080/tcp

# Разрешение P2P портов (libp2p)
ufw allow 40000-40010/tcp
ufw allow 40000-40010/udp

# Включение брандмауэра
ufw enable
ufw status
```

### Шаг 9: Установка Ollama (опционально для локального AI)

```bash
# Установка Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Запуск модели
ollama pull qwen2.5-coder:3b

# Проверка
ollama run qwen2.5-coder:3b "Hello"
```

### Шаг 10: Мониторинг и управление

```bash
# Статус сервиса
systemctl status liberty-reach

# Перезапуск
systemctl restart liberty-reach

# Остановка
systemctl stop liberty-reach

# Логи в реальном времени
journalctl -u liberty-reach -f

# Логи за последний час
journalctl -u liberty-reach --since "1 hour ago"
```

### Шаг 11: Обновление

```bash
# Перейти в директорию
cd /opt/liberty-reach-messenger

# Получить обновления
git pull origin main

# Пересобрать
cargo build --release

# Перезапустить сервис
systemctl restart liberty-reach

# Проверить статус
systemctl status liberty-reach
```

---

## 🔧 Tests

```bash
# Запуск всех тестов
cargo test

# Тесты с логированием
cargo test -- --nocapture

# Тесты конкретного модуля
cargo test crypto
cargo test identity

# Тесты без voice/calls (не требуют аудио-библиотек)
cargo test --no-default-features
```

**Покрываемые модули:**

| Модуль | Тесты |
|--------|-------|
| `crypto` | Шифрование/дешифрование, DH обмен ключами |
| `identity` | Запросы отношений, подтверждение статусов |
| `storage` | Сериализация P2P-передачи файлов |
| `bridge` | Конфигурация Telegram-бота |
| `wallet` | Информация о кошельке, балансы токенов |
| `admin` | Проверка прав, zeroize, верификация |
| `groups` | Создание групп, шифрование, роли |
| `stories` | Создание и просмотр историй |

**Результат:** 24 теста пройдено ✅

---

## 📁 Project Structure

```
liberty-reach-messenger/
├── Cargo.toml              # Зависимости и метаданные
├── .env.local.example      # Шаблон переменных окружения
├── .gitignore              # Игнорируемые файлы
├── README.md               # Документация
├── .env.local              # Секреты (не коммитить!)
├── identity.key            # Приватный ключ (не коммитить!)
├── docs/
│   └── LEGAL_PRIVACY_BG.md # Юридический документ (BG)
└── src/
    ├── main.rs             # Ядро + WebSocket сервер
    ├── identity.rs         # Профили, отношения, статусы
    ├── crypto.rs           # AES-GCM, X25519 DH
    ├── network.rs          # libp2p поведение
    ├── ai.rs               # Ollama + OpenRouter
    ├── storage.rs          # Pinata IPFS
    ├── bridge.rs           # Telegram мост
    ├── wallet.rs           # Web3 Polygon
    ├── exchange.rs         # Агрегатор ликвидности DEX
    ├── admin.rs            # Админ-функции, zeroize, Geo-Trace
    ├── stories.rs          # 24h истории (IPFS)
    ├── voice.rs            # Голосовые сообщения (cpal, opus) [feature]
    ├── calls.rs            # WebRTC звонки [feature]
    └── groups.rs           # Групповые чаты
```

---

## 🔐 Environment Variables

### AI Integration

```bash
# Локальный AI (бесплатно, приватно)
# Установите Ollama: https://ollama.com/
OLLAMA_MODEL=qwen2.5-coder:3b

# Облачный AI (OpenRouter)
OPENROUTER_API_KEY=sk-or-v1-...
```

### Storage (Pinata IPFS)

```bash
PINATA_API_KEY=your-api-key
PINATA_SECRET_KEY=your-secret-key
```

### Web3 (Polygon Network)

```bash
WEB3_RPC_URL=https://polygon-rpc.com
# WEB3_PRIVATE_KEY=...  # Только для отправки транзакций (не коммитить!)
```

### Telegram Bridge

```bash
TELEGRAM_BOT_TOKEN=000000000:AAH...
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

## 🎨 UI Integration (React/Frontend)

### Legal & Privacy Tab

Добавьте вкладку **"Legal & Privacy"** в настройки приложения:

```jsx
// components/Settings/LegalTab.jsx
import LegalTextBG from '../../docs/LEGAL_PRIVACY_BG.md';

function LegalTab() {
  return (
    <div className="legal-privacy-tab">
      <h2>Правна информация и поверителност</h2>
      <div className="legal-content">
        <LegalTextBG />
      </div>
    </div>
  );
}
```

**Путь к файлу:** `docs/LEGAL_PRIVACY_BG.md`

### GDPR Toggle: Clear All Local Metadata

Добавьте кнопку в настройки приватности для мгновенной очистки данных:

```jsx
// components/Settings/PrivacyTab.jsx
function PrivacyTab() {
  const handleZeroize = async () => {
    // Подтверждение действия
    const confirmed = window.confirm(
      '⚠️ WARNING: This will permanently delete all local data, ' +
      'encryption keys, and Cloudflare KV cache. This action cannot be undone!'
    );
    
    if (confirmed) {
      // Вызов API бэкенда для zeroize
      await fetch('/api/admin/zeroize', { method: 'POST' });
      
      // Очистка localStorage
      localStorage.clear();
      
      // Перезагрузка приложения
      window.location.reload();
    }
  };

  return (
    <div className="privacy-tab">
      <h2>Privacy Settings</h2>
      
      <div className="danger-zone">
        <h3>⚠️ Danger Zone</h3>
        <p>Clear all local metadata, encryption keys, and KV cache</p>
        
        <button 
          className="btn-danger"
          onClick={handleZeroize}
        >
          🗑️ Clear all local metadata (Zeroize)
        </button>
      </div>
    </div>
  );
}
```

**Бэкенд обработчик (Rust + WebSocket):**

```rust
// В main.rs обработчик WebSocket команды
"clear_metadata" => {
    app_state.admin_manager.zeroize();
    app_state.admin_manager.clear_cloudflare_kv_cache().await.ok();
    
    // Ответ клиенту
    let response = WSMessage::StatusUpdate {
        status: "All data zeroized".to_string(),
    };
    send_response(response).await;
}
```

### Admin Peer ID Hash Configuration

Для безопасной настройки администратора:

```bash
# 1. Получите ваш PeerID из логов приложения
# Пример: 12D3KooWBkLyzkqWpVZz9JhR5qT8xN3mP4vL2cR6sF9dH1jK8wXy

# 2. Сгенерируйте хэш (Linux/Mac)
echo -n "12D3KooWBkLyzkqWpVZz9JhR5qT8xN3mP4vL2cR6sF9dH1jK8wXy" | sha256sum

# 3. Добавьте в .env.local
ADMIN_PEER_ID_HASH=<ваш_хэш>
```

**Никогда не храните открытый PeerID в .env.local или бинарнике!**

---

## 📜 License

**MIT License**

Свободное ПО — основа цифрового суверенитета.

---

## 👤 Author

**Konstantin** — Decentralized Systems Developer

---

## 🌐 Contact & Support

- **GitHub**: Issues & Pull Requests welcome
- **Telegram**: @liberty_reach_support
- **Email**: zametkikostik@gmail.com

---

## 🙏 Acknowledgments

- **libp2p** — децентрализованные сетевые протоколы
- **Ollama** — локальные большие языковые модели
- **Pinata** — IPFS-хостинг
- **Polygon** — масштабируемый блокчейн
- **Cloudflare** — edge computing и push-уведомления
- **Open Source Community** — криптографические библиотеки (aes-gcm, x25519-dalek, ethers-rs)

---

*Liberty Reach — потому что свобода связи является фундаментальным правом человека.*
