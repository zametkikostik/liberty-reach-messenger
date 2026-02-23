# 🦅 Liberty Reach Messenger

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-cross--platform-green)]()
[![Build](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Version](https://img.shields.io/badge/version-0.3.0-orange)]()

**Свобода достигайки каждого** - безопасный мессенджер нового поколения

[🌐 Web Version](https://liberty-reach-messenger.pages.dev) • [📱 Download APK](https://github.com/YOUR_USERNAME/liberty-reach-messenger/releases) • [📖 Documentation](docs/)

---

## ✨ Особенности

### 🔐 Безопасность
- ✅ **Post-Quantum шифрование** (CRYSTALS-Kyber)
- ✅ **End-to-End шифрование** для всех сообщений
- ✅ **Double Ratchet** для эволюции ключей
- ✅ **Steganography** в медиа-файлах
- ✅ **Mesh сеть** для работы без интернета

### 💰 Крипто-кошелек
- ✅ **15+ блокчейнов** (BTC, ETH, BNB, SOL, TON...)
- ✅ **P2P переводы** между пользователями
- ✅ **DEX Swap** обмен токенов
- ✅ **NFT галерея**
- ✅ **Staking** с APY

### 📞 Коммуникация
- ✅ **VoIP звонки** (WebRTC + ZRTP)
- ✅ **SIP телефония** (звонки на номера)
- ✅ **PTT рации** (как Zello)
- ✅ **Видеоконференции** (до 1000 участников)
- ✅ **Каналы и боты**

### 👨‍👩‍👧‍👦 Социальные функции
- ✅ **Семейные статусы** и отношения
- ✅ **Семейное древо**
- ✅ **Истории** (24 часа)
- ✅ **Стикеры** и реакции
- ✅ **Premium подписки**

---

## 🚀 Быстрый старт

### Web версия (Cloudflare Pages)

```bash
# Просто открой в браузере
https://liberty-reach-messenger.pages.dev
```

### Android приложение

```bash
# Скачать APK
wget https://github.com/YOUR_USERNAME/liberty-reach-messenger/releases/latest/download/app-release.apk

# Установить
adb install app-release.apk
```

### Локальная разработка

```bash
# Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/liberty-reach-messenger.git
cd liberty-reach-messenger

# Сборка Web версии
cd mobile/flutter
flutter build web

# Сборка Android APK
./build-apk.sh
```

---

## 📁 Структура проекта

```
liberty-reach-messenger/
├── 📱 mobile/              # Мобильные приложения
│   ├── flutter/           # Кроссплатформенный Flutter
│   └── android-native/    # Нативный Android
├── 🌐 web/                # Web версия
├── ☁️ cloudflare/         # Backend на Cloudflare
├── 🔐 core/              # Криптографическое ядро
├── 💰 wallet/            # Крипто-кошелек
├── 📞 webrtc/            # VoIP модуль
├── 📡 mesh/              # Mesh сеть
├── 🧪 tests/             # Тесты
└── 📚 docs/              # Документация
```

---

## 🛠️ Технологии

### Frontend
- **Flutter** - кроссплатформенный UI
- **GTK3** - Linux Desktop
- **WebAssembly** - Web версия

### Backend
- **Cloudflare Workers** - serverless backend
- **Durable Objects** - состояние сессий
- **R2 Storage** - зашифрованное хранилище
- **Queues** - асинхронная обработка

### Cryptography
- **Rust** - низкоуровневая криптография
- **CRYSTALS-Kyber** - Post-Quantum KEM
- **X25519/Ed25519** - классическая криптография
- **AES-256-GCM** - симметричное шифрование

### Blockchain
- **Bitcoin** - UTXO модель
- **Ethereum** - смарт-контракты
- **TON** - быстрые транзакции
- **Solana** - высокая пропускная способность

---

## 📊 Возможности

| Функция | Free | Premium | Business | Enterprise |
|---------|------|---------|----------|------------|
| Сообщения | ✅ | ✅ | ✅ | ✅ |
| VoIP звонки | ✅ | ✅ | ✅ | ✅ |
| Конференции | 10 уч. | 50 уч. | 300 уч. | 1000 уч. |
| Крипто-кошелек | ✅ | ✅ | ✅ | ✅ |
| Каналы | ✅ | ✅ | ✅ | ✅ |
| Боты | ✅ | ✅ | ✅ | ✅ |
| Стикеры | ✅ | ✅ | ✅ | ✅ |
| Premium реакции | ❌ | ✅ | ✅ | ✅ |
| Перевод сообщений | ❌ | ✅ | ✅ | ✅ |
| Бизнес аккаунт | ❌ | ❌ | ✅ | ✅ |
| API доступ | ❌ | ❌ | ✅ | ✅ |
| Поддержка | ❌ | ❌ | Приоритет | 24/7 |
| Хранилище | 1 GB | 100 GB | 1 TB | ∞ |

---

## 🔒 Безопасность

### Шифрование
```
Сообщения → PQ (Kyber768) + X25519 → AES-256-GCM → Double Ratchet
```

### Хранение ключей
```
Ключи → Secure Enclave / TrustZone → Никогда не покидают устройство
```

### Восстановление
```
Профиль → Shamir's Secret (3 из 5) → Восстановление без сервера
```

---

## 🤝 Contributing

Мы приветствуем вклад! Пожалуйста:

1. Fork репозиторий
2. Создай feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Открой Pull Request

### Разработка

```bash
# Установить зависимости
cd mobile/flutter
flutter pub get

# Запустить тесты
flutter test

# Запустить линтер
flutter analyze

# Собрать для debug
flutter run
```

---

## 📝 Лицензия

MIT License - см. файл [LICENSE](LICENSE) для деталей.

---

## 📞 Контакты

- **Website**: https://libertyreach.internal
- **Email**: dev@libertyreach.internal
- **Telegram**: @libertyreach
- **Twitter**: @libertyreach

---

## 🙏 Благодарности

- **Cloudflare** - за инфраструктуру
- **Flutter Team** - за отличный фреймворк
- **Rust Community** - за криптографические библиотеки
- **Всем контрибьюторам** - за помощь в развитии

---

## 📈 Статистика

[![Stars](https://img.shields.io/github/stars/YOUR_USERNAME/liberty-reach-messenger?style=social)]()
[![Forks](https://img.shields.io/github/forks/YOUR_USERNAME/liberty-reach-messenger?style=social)]()
[![Watchers](https://img.shields.io/github/watchers/YOUR_USERNAME/liberty-reach-messenger?style=social)]()

---

<div align="center">

**Made with ❤️ by Liberty Reach Team**

[🔝 Back to Top](#-liberty-reach-messenger)

</div>
