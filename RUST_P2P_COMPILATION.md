# 🦀 RUST P2P - КОМПИЛЯЦИЯ ДЛЯ ANDROID

**Статус:** ✅ Код готов, требуется NDK для компиляции

---

## 📋 ТРЕБОВАНИЯ

### 1. Android NDK

```bash
# Установить через Android Studio:
# Tools → SDK Manager → SDK Tools → NDK (Side by side)

# ИЛИ через sdkmanager:
sdkmanager "ndk;25.2.9519653"
```

### 2. Rust Targets

```bash
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
```

### 3. LLVM для Android

```bash
# NDK включает clang для компиляции
export NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
export PATH=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
```

---

## 🏗️ КОМПИЛЯЦИЯ

### Для ARM64 (современные телефоны):

```bash
cd rust_p2p

cargo ndk \
  --target aarch64-linux-android \
  --platform 21 \
  build --release
```

### Для ARMv7 (старые телефоны):

```bash
cargo ndk \
  --target armv7-linux-androideabi \
  --platform 21 \
  build --release
```

### Для x86_64 (эмуляторы):

```bash
cargo ndk \
  --target x86_64-linux-android \
  --platform 21 \
  build --release
```

---

## 📦 КОПИРОВАНИЕ .so ФАЙЛОВ

```bash
# Создать директорию JNI libs
mkdir -p mobile/android/app/src/main/jniLibs/arm64-v8a
mkdir -p mobile/android/app/src/main/jniLibs/armeabi-v7a
mkdir -p mobile/android/app/src/main/jniLibs/x86_64

# Копировать .so файлы
cp target/aarch64-linux-android/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/arm64-v8a/libliberty_p2p.so

cp target/armv7-linux-androideabi/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/armeabi-v7a/libliberty_p2p.so

cp target/x86_64-linux-android/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/x86_64/libliberty_p2p.so
```

---

## 🚀 СБОРКА APK

```bash
cd mobile

# Получить зависимости
flutter pub get

# Собрать APK
flutter build apk --release --split-per-abi
```

---

## 📊 РЕЗУЛЬТАТ

После компиляции APK будет содержать:
- ✅ Rust P2P ядро (liberty_p2p.so)
- ✅ Kademlia DHT для глобального обнаружения
- ✅ Relay Client для NAT traversal
- ✅ Gossipsub для messaging
- ✅ E2EE шифрование (AES-256-GCM)

---

## 🌍 GLOBAL P2P FEATURES

### Kademlia DHT
- Глобальное обнаружение пиров
- Маршрутизация через интернет
- Устойчивость к выходу узлов

### Relay Client
- Общение через NAT
- Hole punching (DCUtR)
- Relay сервера для помощи

### Gossipsub
- Pub/sub messaging
- Topic-based channels
- Efficient flooding

---

## 🛠️ ALTERNATIVE: Dart P2P (уже работает)

Если Rust компиляция сложна, используйте **real_p2p_service.dart**:
- ✅ UDP multicast для локального обнаружения
- ✅ TCP для прямого соединения
- ✅ Работает БЕЗ NDK
- ✅ Уже в APK

**Минусы:**
- ⚠️ Только локальная сеть (нет глобального)
- ⚠️ Нет Kademlia DHT
- ⚠️ Нет Relay для NAT

---

**Бро, выбирай: Rust для глобального P2P или Dart для локального!** 🦀🚀

*Liberty Reach Team*  
*23 марта 2026 г.*
