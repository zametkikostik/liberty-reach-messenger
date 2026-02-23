# 🦅 Liberty Reach Messenger v0.2.0
## Полноценный мессенджер с крипто-кошельком и функциями Telegram

---

## 🎯 ЧТО ЭТО

**Liberty Reach** - это **полноценный мессенджер** который включает:

### ✅ От Telegram:
- ✅ **Каналы** - публичные и приватные
- ✅ **Боты** - поддержка ботов с командами
- ✅ **Стикеры** - стикерпаки, анимированные стикеры
- ✅ **Истории (Stories)** - 24 часа
- ✅ **Реакции** - эмодзи реакции на сообщения
- ✅ **Папки** - организация чатов
- ✅ **Ответы** - reply на сообщения

### ✅ От криптовалютных кошельков:
- ✅ **Мульти-блокчейн** - 15+ блокчейнов
- ✅ **P2P переводы** - между пользователями
- ✅ **DEX Swap** - обмен токенов
- ✅ **NFT** - просмотр и перевод
- ✅ **Staking** - стейкинг монет
- ✅ **История транзакций**

### ✅ Оригинальные функции:
- ✅ **Post-Quantum шифрование**
- ✅ **Mesh сеть** (офлайн режим)
- ✅ **Профиль перманентный**
- ✅ **VoIP вызовы**

---

## 💰 КРИПТОВАЛЮТНЫЙ КОШЕЛЕК

### Поддерживаемые блокчейны (15+):

| Блокчейн | Символ | Статус |
|----------|--------|--------|
| Bitcoin | BTC | ✅ |
| Ethereum | ETH | ✅ |
| BNB Smart Chain | BNB | ✅ |
| Polygon | MATIC | ✅ |
| Solana | SOL | ✅ |
| TON | TON | ✅ |
| Tron | TRX | ✅ |
| Avalanche | AVAX | ✅ |
| Cardano | ADA | ✅ |
| Dogecoin | DOGE | ✅ |
| Litecoin | LTC | ✅ |
| Bitcoin Cash | BCH | ✅ |
| Polkadot | DOT | ✅ |
| Chainlink | LINK | ✅ |
| Uniswap | UNI | ✅ |
| **Liberty Coin** | **LBR** | ✅ Native |

### Функции кошелька:

```
✅ Создание/импорт кошелька
✅ Мульти-блокчейн адреса
✅ Отправка криптовалюты
✅ P2P переводы по user_id
✅ DEX Swap (обмен токенов)
✅ Просмотр баланса (USD)
✅ История транзакций
✅ NFT галерея
✅ Staking с APY
✅ Экспорт/импорт приватных ключей
✅ PIN код для транзакций
✅ Biometric аутентификация
```

### Пример использования:

```cpp
// Создание кошелька
auto& wallet = CryptoWallet::getInstance();
std::string mnemonic = wallet.createWallet("password123");
// mnemonic: "liberty reach secure private ..."

// Получение адреса
std::string btc_address = wallet.getAddress(Blockchain::BITCOIN);
// "bc1q..."

std::string eth_address = wallet.getAddress(Blockchain::ETHEREUM);
// "0x..."

// Отправка BTC
std::string tx_id = wallet.send(
    "bc1qrecipient...",  // кому
    0.001,               // сколько BTC
    Blockchain::BITCOIN,
    "Привет!"            // memo
);

// P2P перевод пользователю Liberty Reach
std::string tx_id = wallet.sendToUser(
    "user_12345",        // Liberty Reach user_id
    10.0,                // сколько токенов
    Blockchain::TON,
    "За товар"
);

// Swap токенов
std::string swap_id = wallet.swap(
    "ETH",               // из
    "USDT",              // в
    1.0,                 // количество
    0.5                  // slippage %
);

// Staking
std::string stake_id = wallet.stake(
    1000.0,              // количество
    Blockchain::SOLANA,
    "validator_pubkey"
);

// Проверка баланса
auto balance = wallet.getBalance(Blockchain::ETHEREUM);
std::cout << "Balance: " << balance.amount << " ETH" << std::endl;
std::cout << "USD Value: $" << balance.usd_value << std::endl;
```

---

## 📱 ФУНКЦИИ TELEGRAM

### 1. Каналы

```cpp
// Создание канала
auto& features = FeaturesManager::getInstance();

Channel channel = features.createChannel(
    "Новости Liberty Reach",  // название
    "Официальные новости",     // описание
    ChannelType::BROADCAST     // тип
);

// Публикация поста
ChannelPost post = features.postToChannel(
    channel.id,
    "Запуск версии 0.2.0! 🚀",
    {"https://image.png"}  // медиа
);

// Подписка
features.subscribeToChannel(channel.id);

// Получение постов
auto posts = features.getChannelPosts(channel.id, 50);
```

### 2. Боты

```cpp
// Создание бота
Bot bot = features.createBot(
    "MyBot",
    "bot_token_12345"
);

// Команды бота
std::vector<BotCommand> commands = {
    {"/start", "Запустить бота"},
    {"/help", "Помощь"},
    {"/price", "Цена токена"}
};
features.setBotCommands(bot.id, commands);

// Обработка сообщений
std::string response = features.handleBotMessage(
    bot.id,
    "/price"
);
```

### 3. Стикеры

```cpp
// Создание стикерпака
StickerPack pack = features.createStickerPack(
    "liberty_stickers",
    "Liberty Reach Стикеры"
);

// Добавление стикера
Sticker sticker;
sticker.id = "sticker_1";
sticker.file_url = "https://sticker.png";
sticker.emoji = "🦅";
features.addStickerToPack(pack.id, sticker);

// Установка пака
features.installStickerPack(pack.id);

// Поиск по эмодзи
auto stickers = features.searchStickers("🔥");
```

### 4. Истории (Stories)

```cpp
// Создание истории
Story story = features.createStory(
    "https://photo.jpg",   // медиа
    "Привет! 👋",          // текст
    15                     // секунд
);

// Просмотр историй
auto stories = features.getStories("friend_id");

// Удаление
features.deleteStory(story.id);
```

### 5. Реакции

```cpp
// Добавить реакцию
features.addReaction("message_123", "👍");
features.addReaction("message_123", "❤️");

// Получить реакции
auto reactions = features.getMessageReactions("message_123");
```

### 6. Папки

```cpp
// Создание папки
ChatFolder folder = features.createFolder("Работа");
folder.chat_ids = {"chat1", "chat2"};
folder.icon_emoji = "💼";

// Получить папки
auto folders = features.getFolders();
```

---

## 🚀 СБОРКА

### Требования

```bash
# Linux Mint/Ubuntu/Debian
sudo apt install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    libsodium-dev \
    libgtk-3-dev \
    libjsoncpp-dev \
    libgstreamer1.0-dev \
    libopus-dev \
    rustc \
    cargo
```

### Сборка

```bash
cd /home/kostik/liberty-reach-messenger
./build.sh
```

### Запуск

```bash
# Desktop версия
./build/liberty_reach_desktop

# CLI версия
./build/liberty_reach_cli
```

---

## 📊 ФУНКЦИОНАЛ

### Мессенджер:
- ✅ Личные сообщения (E2EE)
- ✅ Групповые чаты
- ✅ **Каналы** (неограниченно подписчиков)
- ✅ **Боты** (с командами)
- ✅ **Стикеры** (анимированные)
- ✅ **Истории** (24 часа)
- ✅ **Реакции** (эмодзи)
- ✅ **Папки** (организация)
- ✅ **Ответы** (reply)
- ✅ **Пересылка**
- ✅ **Избранное**

### Крипто-кошелек:
- ✅ **15+ блокчейнов**
- ✅ **P2P переводы**
- ✅ **DEX Swap**
- ✅ **NFT галерея**
- ✅ **Staking**
- ✅ **История**
- ✅ **Безопасность** (PIN, biometric)

### VoIP:
- ✅ Голосовые вызовы
- ✅ Видео вызовы
- ✅ Групповые звонки

### Mesh сеть:
- ✅ Bluetooth LE
- ✅ WiFi Direct
- ✅ LoRa (до 50км)

---

## 🔐 БЕЗОПАСНОСТЬ

### Кошелек:
- ✅ Шифрование AES-256
- ✅ PIN код для транзакций
- ✅ Biometric (отпечаток, лицо)
- ✅ Recovery phrase (12/24 слова)
- ✅ Экспорт приватных ключей

### Мессенджер:
- ✅ Post-Quantum (Kyber768)
- ✅ X25519 ECDH
- ✅ AES-256-GCM
- ✅ Double Ratchet
- ✅ Профиль перманентный

---

## 💎 LIBERTY COIN (LBR)

Нативный токен Liberty Reach:

```
Название: Liberty Coin
Символ: LBR
Блокчейн: Liberty Reach Chain
Тип: Native
Эмиссия: 1,000,000,000 LBR
```

### Использование:
- ✅ Оплата комиссий
- ✅ Стейкинг
- ✅ Голосование (DAO)
- ✅ Покупка стикеров
- ✅ Премиум функции

---

## 📁 СТРУКТУРА ПРОЕКТА

```
liberty-reach-messenger/
├── core/
│   ├── crypto/           # Rust крипто
│   ├── include/
│   │   ├── liberty_reach_crypto.h
│   │   ├── network_client.h
│   │   └── telegram_features.h  # ✅ НОВОЕ
│   └── src/
│       └── network_client.cpp
├── wallet/               # ✅ НОВЫЙ МОДУЛЬ
│   ├── include/
│   │   └── crypto_wallet.h
│   └── src/
│       └── crypto_wallet.cpp
├── desktop/
│   └── src/
│       └── main_full.cpp  # С кошельком
├── cli/
├── webrtc/
├── mesh/
└── tests/
```

---

## 🎯 ИТОГ

**Liberty Reach v0.2.0** - это:

| Функция | Telegram | WhatsApp | Signal | **Liberty Reach** |
|---------|----------|----------|--------|-------------------|
| Сообщения | ✅ | ✅ | ✅ | ✅ |
| Каналы | ✅ | ❌ | ❌ | ✅ |
| Боты | ✅ | ❌ | ❌ | ✅ |
| Стикеры | ✅ | ❌ | ❌ | ✅ |
| Истории | ✅ | ✅ | ❌ | ✅ |
| Крипто | ❌ | ❌ | ❌ | ✅ |
| P2P | ❌ | ❌ | ❌ | ✅ |
| Mesh | ❌ | ❌ | ❌ | ✅ |
| PQ Crypto | ❌ | ❌ | ❌ | ✅ |
| Профиль | ❌ | ❌ | ❌ | ✅ Перманентный |

**Liberty Reach объединяет лучшее от всех!** 🦅

---

## 📞 КОНТАКТЫ

- **Website**: https://libertyreach.internal
- **Email**: dev@libertyreach.internal
- **Docs**: /docs/

**Liberty Reach - Мессенджер будущего уже сегодня!** 🚀
