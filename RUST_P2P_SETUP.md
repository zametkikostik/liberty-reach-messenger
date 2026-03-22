# 🦀 RUST P2P - INSTALLATION & SETUP

**Version:** v0.18.0-p2p  
**Status:** ✅ Ready to build

---

## 📋 PREREQUISITES

### 1. Rust Toolchain

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify
rustc --version
cargo --version

# Add targets for mobile
rustup target add aarch64-linux-android  # Android ARM64
rustup target add armv7-linux-androideabi  # Android ARMv7
rustup target add x86_64-linux-android  # Android x86_64
```

### 2. Flutter Rust Bridge

```bash
# Install flutter_rust_bridge codegen
cargo install flutter_rust_bridge_codegen

# Verify
flutter_rust_bridge_codegen --version
```

### 3. Android NDK (for Rust compilation)

```bash
# In Android Studio:
# Tools → SDK Manager → SDK Tools → NDK (Side by side)
# Or via command line:
sdkmanager "ndk;25.2.9519653"
```

---

## 🚀 BUILD INSTRUCTIONS

### Step 1: Generate Flutter Bridge

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign

# Generate Dart bindings from Rust
flutter_rust_bridge_codegen \
  --rust-input rust_p2p/src/lib.rs \
  --dart-output mobile/lib/services/rust_p2p_bridge.dart \
  --c-output mobile/lib/services/rust_p2p_bridge.h \
  --rust-crate-dir rust_p2p
```

### Step 2: Build Rust for Android

```bash
cd rust_p2p

# Android ARM64 (most modern phones)
cargo ndk --target aarch64-linux-android build --release

# Android ARMv7 (older phones)
cargo ndk --target armv7-linux-androideabi build --release

# Android x86_64 (emulators)
cargo ndk --target x86_64-linux-android build --release
```

### Step 3: Copy Rust .so files to Flutter

```bash
# Create JNI libs directory
mkdir -p mobile/android/app/src/main/jniLibs/arm64-v8a
mkdir -p mobile/android/app/src/main/jniLibs/armeabi-v7a
mkdir -p mobile/android/app/src/main/jniLibs/x86_64

# Copy compiled .so files
cp target/aarch64-linux-android/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/arm64-v8a/libliberty_p2p.so

cp target/armv7-linux-androideabi/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/armeabi-v7a/libliberty_p2p.so

cp target/x86_64-linux-android/release/libliberty_p2p.so \
   mobile/android/app/src/main/jniLibs/x86_64/libliberty_p2p.so
```

### Step 4: Build Flutter APK

```bash
cd mobile

# Get dependencies
flutter pub get

# Build APK with Rust
flutter build apk --release --split-per-abi

# APKs will be in:
# mobile/build/app/outputs/flutter-apk/
```

---

## 📱 APK OUTPUT

| APK | Size | Architecture |
|-----|------|--------------|
| app-arm64-v8a-release.apk | ~45 MB | Modern phones (vivo Y53s) |
| app-armeabi-v7a-release.apk | ~38 MB | Older phones |
| app-x86_64-release.apk | ~48 MB | Emulators, tablets |
| app-release.apk | ~130 MB | Universal (all architectures) |

---

## ✅ VERIFICATION

### Test Rust Core

```bash
cd rust_p2p

# Run Rust tests
cargo test

# Expected output:
# test tests::test_identity_creation ... ok
# test tests::test_e2ee_roundtrip ... ok
# test tests::test_sign_verify ... ok
```

### Test Flutter Integration

```bash
cd mobile

# Run Flutter tests
flutter test

# Expected: All tests pass
```

---

## 🐛 TROUBLESHOOTING

### Error: "flutter_rust_bridge_codegen: command not found"

```bash
# Install
cargo install flutter_rust_bridge_codegen

# Make sure cargo bin is in PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Error: "linker `aarch64-linux-android-ld` not found"

```bash
# Install Android NDK
sdkmanager "ndk;25.2.9519653"

# Set NDK path
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
```

### Error: "undefined reference to `JNI_OnLoad'"

```bash
# Make sure crate-type includes "cdylib" in Cargo.toml
[lib]
crate-type = ["cdylib", "rlib"]
```

---

## 📚 NEXT STEPS

1. ✅ Build Rust P2P core
2. ✅ Generate Flutter bridge
3. ✅ Copy .so files to Flutter
4. ✅ Build APK
5. ⏳ Test E2EE 1-to-1 chats
6. ⏳ Implement group chats
7. ⏳ Add WebRTC calls

---

**«Rust P2P Core ready for production!»** 🦀

*Liberty Reach Team*  
*22 марта 2026 г.*
