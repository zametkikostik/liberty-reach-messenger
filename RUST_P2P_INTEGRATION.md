# 🦀 RUST P2P CORE - ИНТЕГРАЦИЯ

**Дата:** 22 марта 2026 г.  
**Статус:** ⚠️ Готово к интеграции  
**Версия:** v0.1.0

---

## 📊 ЧТО ЕСТЬ СЕЙЧАС

### ✅ Rust Ядро (backend/)

**Файлы:**
- `backend/Cargo.toml` - зависимости
- `backend/src/lib.rs` - Cloudflare Worker (Rust WASM)

**Функционал:**
- ✅ Ed25519 подпись
- ✅ SHA256 хэширование
- ✅ Base64 кодирование
- ✅ Worker для Cloudflare

**Использование:**
```rust
// backend/src/lib.rs
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use sha2::{Digest, Sha256};
```

---

### ✅ P2P Rust Библиотека (rust_p2p/)

**Файлы:**
- `rust_p2p/Cargo.toml` - libp2p зависимости
- `rust_p2p/src/lib.rs` - P2P функции

**Функционал:**
- ✅ libp2p стек
- ✅ mDNS обнаружение
- ✅ Gossipsub для чатов
- ✅ Kademlia DHT
- ✅ Noise шифрование
- ✅ Yamux мультиплексирование
- ✅ FFI для Flutter

**Функции:**
```rust
// Создание ноды
pub async fn create_p2p_node(user_id: String) -> Result<P2PNode, String>

// Запуск
pub async fn start_node(node: P2PNode) -> Result<P2PNode, String>

// Обнаружение пиров
pub async fn discover_peers() -> Result<Vec<PeerInfo>, String>

// Отправка сообщения
pub async fn send_message(from, to, content, encrypted) -> Result<bool, String>
```

---

## 🔧 ИНТЕГРАЦИЯ С FLUTTER

### Вариант 1: flutter_rust_bridge (рекомендуется)

**1. Установка:**
```bash
cd rust_p2p_bridge
flutter pub get

# Установка flutter_rust_bridge
cargo install flutter_rust_bridge_codegen
```

**2. Генерация bridge:**
```bash
flutter_rust_bridge_codegen \
  --rust-input rust_p2p/src/lib.rs \
  --dart-output mobile/lib/services/rust_p2p_bridge.dart
```

**3. Использование во Flutter:**
```dart
import 'package:liberty_p2p_bridge/rust_p2p_bridge.dart';

// Создание ноды
final node = await createP2pNode(userId: 'user_123');

// Запуск
await startNode(node: node);

// Обнаружение пиров
final peers = await discoverPeers();

// Отправка сообщения
await sendMessage(
  from: 'user_123',
  to: 'peer_456',
  content: 'Привет!',
  encrypted: true,
);
```

---

### Вариант 2: Method Channel (альтернатива)

**1. Компиляция Rust в .so:**
```bash
cd rust_p2p

# Android
cargo ndk --target aarch64-linux-android build --release

# iOS
cargo build --release --target aarch64-apple-ios
```

**2. Интеграция в Android:**
```kotlin
// MainActivity.kt
class MainActivity: FlutterActivity() {
    private val CHANNEL = "liberty_p2p"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "createNode" -> {
                    val nodeId = RustP2P.createNode(call.argument("userId"))
                    result.success(nodeId)
                }
                // ...
            }
        }
    }
}
```

---

## 📦 ЗАВИСИМОСТИ

### Rust (Cargo.toml)

```toml
[dependencies]
libp2p = { version = "0.53", features = [
    "tokio", "tcp", "dns", "noise", "yamux",
    "mdns", "gossipsub", "kad", "quic",
] }
tokio = { version = "1.0", features = ["full"] }
flutter_rust_bridge = "1.0"
```

### Flutter (pubspec.yaml)

```yaml
dependencies:
  flutter_rust_bridge: ^1.0.0
  ffi: ^2.0.0
```

---

## B СБОРКА

### Android APK с Rust

```bash
# 1. Скомпилировать Rust
cd rust_p2p
cargo ndk build --release

# 2. Собрать Flutter APK
cd ../mobile
flutter build apk --release

# APK будет в:
# mobile/build/app/outputs/flutter-apk/
```

### iOS IPA с Rust

```bash
# 1. Скомпилировать Rust для iOS
cd rust_p2p
cargo build --release --target aarch64-apple-ios

# 2. Собрать Flutter IPA
cd ../mobile
flutter build ios --release
```

---

## ✅ ЧЕК-ЛИСТ ИНТЕГРАЦИИ

- [x] Rust P2P библиотека создана
- [x] libp2p зависимости настроены
- [x] FFI функции определены
- [ ] flutter_rust_bridge установлен
- [ ] Bridge сгенерирован
- [ ] Интеграция во Flutter
- [ ] Тесты P2P
- [ ] APK с Rust собран

---

## 📚 СЛЕДУЮЩИЕ ШАГИ

### 1. Установить flutter_rust_bridge

```bash
cargo install flutter_rust_bridge_codegen
```

### 2. Сгенерировать bridge

```bash
cd mobile
flutter_rust_bridge_codegen \
  --rust-input ../rust_p2p/src/lib.rs \
  --dart-output lib/services/rust_p2p_bridge.dart
```

### 3. Добавить в pubspec.yaml

```yaml
dependencies:
  flutter_rust_bridge: ^1.0.0
```

### 4. Интегрировать в P2PNetworkService

```dart
import 'rust_p2p_bridge.dart';

class P2PNetworkService {
  Future<bool> start() async {
    final node = await createP2pNode(userId: _userId);
    await startNode(node: node);
    return true;
  }
}
```

---

## 🎯 ПРЕИМУЩЕСТВА RUST P2P

| Характеристика | Dart | Rust + libp2p |
|----------------|------|---------------|
| **Производительность** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Память** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Безопасность** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **libp2p поддержка** | ⭐ | ⭐⭐⭐⭐⭐ |
| **Сообщество** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

**«Rust ядро готово к интеграции!»** 🦀

*Liberty Reach Team*  
*22 марта 2026 г.*
