# 🟢 HYBRID CI/CD SETUP DOCUMENTATION

## Project: Liberty Reach (Flutter + Rust)

---

## 📋 OVERVIEW

This setup enables **hybrid build system** where:
- **Local builds** use physical `.jks` file + `key.properties`
- **GitHub builds** use `BASE64` decoded keystore from secrets

---

## 🏗️ ARCHITECTURE

```
┌─────────────────────────────────────────────────────────┐
│              HYBRID CI/CD SYSTEM                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  LOCAL (Linux Mint)          GITHUB ACTIONS             │
│  ┌──────────────────┐       ┌──────────────────┐       │
│  │  key.properties  │       │  KEYSTORE_BASE64 │       │
│  │  upload-keystore │       │  Secrets         │       │
│  │  .jks file       │       │  (Environment)   │       │
│  └────────┬─────────┘       └────────┬─────────┘       │
│           │                          │                  │
│           └──────────┬───────────────┘                  │
│                      │                                  │
│              ┌───────▼────────┐                         │
│              │  build.gradle  │                         │
│              │  (Hybrid Logic)│                         │
│              └───────┬────────┘                         │
│                      │                                  │
│           ┌──────────▼──────────┐                       │
│           │  Signed APK/AAB     │                       │
│           └─────────────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 FILES CREATED

| File | Purpose |
|------|---------|
| `mobile/android/app/build.gradle` | Hybrid signing config |
| `.github/workflows/build.yml` | CI/CD workflow |
| `.env.example` | Environment template |
| `src/config.rs` | Rust config loader |
| `mobile/lib/services/api_service.dart` | Flutter config service |

---

## 🔐 LOCAL ENVIRONMENT SETUP

### Step 1: Create Keystore

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile

# Create keystore
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# Enter password when prompted
```

### Step 2: Create key.properties

```bash
cd mobile/android

nano key.properties
```

**Paste:**
```properties
storePassword=your_password_here
keyPassword=your_password_here
keyAlias=upload
storeFile=upload-keystore.jks
```

### Step 3: Build Locally

```bash
cd mobile

flutter clean
flutter pub get
flutter build apk --release
```

---

## 🚀 GITHUB ACTIONS SETUP

### Step 1: Add Secrets to GitHub

Go to: https://github.com/zametkikostik/liberty-reach-messenger/settings/secrets/actions

**Add these secrets:**

| Secret Name | Value |
|-------------|-------|
| `KEYSTORE_BASE64` | `cat android/app/upload-keystore.jks \| base64 \| xclip -sel clip` |
| `KEYSTORE_PASSWORD` | Your keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | Your key password |
| `RPC_URL` | `https://polygon-rpc.com` |
| `OPENROUTER_API_KEY` | Your OpenRouter key |
| `SECRET_LOVE_KEY` | Your secret key (min 16 chars) |
| `PINATA_API_KEY` | Your Pinata API key |
| `PINATA_SECRET_KEY` | Your Pinata secret key |
| `DOCKER_USERNAME` | Docker Hub username (optional) |
| `DOCKER_PASSWORD` | Docker Hub password (optional) |

### Step 2: Trigger Build

```bash
# Create tag for release
git tag v0.4.0-fortress-stable

# Push tag (triggers build)
git push origin v0.4.0-fortress-stable
```

### Step 3: Download APK

After build completes:
- **Artifacts**: https://github.com/zametkikostik/liberty-reach-messenger/actions
- **Release**: https://github.com/zametkikostik/liberty-reach-messenger/releases

---

## 🔧 CONFIGURATION PRIORITY

### Rust Backend:

```
1. System Environment Variables (CI/CD)
   ↓
2. .env.local file (Local dev)
   ↓
3. Default values (Fallback)
```

### Flutter Frontend:

```
1. Build-time environment variables (dart-define)
   ↓
2. .env file (Local dev)
   ↓
3. Default values (Fallback)
```

---

## 📊 ENVIRONMENT VARIABLES

### Required for Build:

| Variable | Purpose | Source |
|----------|---------|--------|
| `STORE_FILE` | Keystore file path | GitHub Secrets |
| `STORE_PASSWORD` | Keystore password | GitHub Secrets |
| `KEY_ALIAS` | Key alias name | GitHub Secrets |
| `KEY_PASSWORD` | Key password | GitHub Secrets |

### Required for Runtime:

| Variable | Purpose | Source |
|----------|---------|--------|
| `RPC_URL` | Blockchain RPC | GitHub Secrets / .env.local |
| `OPENROUTER_API_KEY` | AI integration | GitHub Secrets / .env.local |
| `SECRET_LOVE_KEY` | Encryption salt | GitHub Secrets / .env.local |
| `PINATA_API_KEY` | IPFS upload | GitHub Secrets / .env.local |
| `PINATA_SECRET_KEY` | IPFS secret | GitHub Secrets / .env.local |

---

## 🧪 TESTING

### Local Build Test:

```bash
cd mobile

# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --release --split-per-abi

# Check output
ls -lh build/app/outputs/flutter-apk/
```

### CI/CD Test:

1. Push to `develop` branch (triggers workflow)
2. Check Actions tab
3. Download artifacts

---

## 🔐 SECURITY NOTES

### ✅ DO:
- Add secrets to GitHub Secrets
- Use `.env.local` for local development
- Add `.env.local` to `.gitignore`
- Use environment variables in CI/CD

### ❌ DON'T:
- Commit `.env.local` to git
- Commit `key.properties` to git
- Commit `upload-keystore.jks` to git
- Hardcode secrets in code

---

## 📦 BUILD OUTPUTS

### APK (Direct Installation):
- `app-armeabi-v7a-release.apk` (32-bit)
- `app-arm64-v8a-release.apk` (64-bit)
- `app-x86_64-release.apk` (emulator)

### AAB (Google Play):
- `app-release.aab`

### Backend Binary:
- `liberty-sovereign` (Linux)
- `liberty-sovereign.exe` (Windows)

### Docker Image:
- `zametkikostik/liberty-sovereign:latest`

---

## 🎯 WORKFLOW TRIGGERS

| Event | Action |
|-------|--------|
| Push to `main` | Build & Test |
| Push to `develop` | Build & Test |
| Push tag `v*` | Build + Release |
| Pull Request | Build & Test |
| Manual (workflow_dispatch) | Build |

---

## 📖 ADDITIONAL RESOURCES

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Flutter Signing**: https://docs.flutter.dev/deployment/android
- **Rust CI/CD**: https://github.com/actions-rs

---

**Built for freedom, encrypted for life.** 🏰
