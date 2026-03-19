# 🚀 Liberty Reach - Secure Entry Flow Setup Guide

## ✅ Completed Implementation

### Files Created/Updated:

```
mobile/lib/
├── main.dart                          ✅ Updated (ThemeService integration)
├── initial_screen.dart                ✅ Updated (TorRitualWidget + animations)
├── screens/
│   ├── splash_screen.dart             ✅ NEW (Biometric authentication)
│   └── settings_screen.dart           ✅ NEW (Theme toggle + settings)
├── services/
│   ├── theme_service.dart             ✅ NEW (Ghost/Love themes)
│   └── biometric_service.dart         ✅ NEW (Fingerprint/Face ID)
└── widgets/
    ├── tor_ritual_widget.dart         ✅ NEW (Onion progress indicator)
    └── theme_switcher_widget.dart     ✅ NEW (Theme toggle UI)
```

---

## 🎨 Features Implemented

### 1. Tor Ritual Widget 🧅
- CustomPainter onion shape with layered petals
- Pulsing glow animation (1.5s cycle)
- Dynamic status text:
  - 0-10%: "Инициализация..."
  - 10-20%: "Генерация ключей..."
  - 20-30%: "Поиск входного узла..."
  - 30-40%: "Поиск среднего узла..."
  - 40-50%: "Поиск выходного узла..."
  - 50-60%: "Шифруем туннель..."
  - 60-70%: "Устанавливаем цепь..."
  - 70-80%: "Проверка соединения..."
  - 80-90%: "Почти в безопасности..."
  - 90-100%: "Финализация..."
  - 100%: "✓ В безопасности"
- Glassmorphism card with BackdropFilter

### 2. Theme Service 🎨
- **Ghost Mode**: Neon green (#00FF87, #00FFD5, #7BFF00)
- **Love Story**: Pink/Purple (#FF0080, #BD00FF, #FF2E63)
- Persistent storage (SharedPreferences)
- ChangeNotifier for reactive UI

### 3. Biometric Service 🔐
- Fingerprint/Face ID authentication
- Panic wipe after 3 failed attempts
- Secure storage integration
- Enable/disable toggle

### 4. Splash Screen 🛡️
- Pulsing logo animation
- Biometric prompt
- Fade transition to InitialScreen
- Auto-close on failed attempts

### 5. Initial Screen 🏠
- TorRitualWidget integration
- Staggered fade-out animation
- Theme switcher (Ghost/Love)
- Chat list placeholder

---

## 📦 Dependencies Required

In `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Biometric authentication
  local_auth: ^2.1.6
  
  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # Crypto (existing)
  cryptography: ^2.7.0
  encrypt: ^5.0.3
```

---

## 🔧 Setup Instructions

### Step 1: Install Dependencies

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile
flutter pub get
```

### Step 2: Android Configuration

Already configured in `android/app/src/main/AndroidManifest.xml`:
- ✅ Internet permissions
- ✅ Foreground service for Tor

### Step 3: Run the App

```bash
flutter run
```

---

## 🎯 User Flow

```
┌─────────────────────────────────────┐
│ 1. Splash Screen                    │
│    - Pulsing logo                   │
│    - Biometric prompt               │
│    - 3 attempts → Panic wipe        │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│ 2. Initial Screen                   │
│    - Enable Tor button              │
│    - Tor Ritual Widget appears      │
│    - Onion fills with progress      │
│    - Status text updates            │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│ 3. Tor Connected (100%)             │
│    - Auto-start registration        │
│    - Generate keys                  │
│    - Register on backend            │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│ 4. Staggered Transition             │
│    - Fade out ritual                │
│    - Reveal chat list               │
│    - Success dialog                 │
└─────────────────────────────────────┘
```

---

## 🎨 Theme Switching

### In Settings Screen:
```dart
// Ghost Mode
themeService.setTheme(ThemeService.ghostMode);

// Love Story
themeService.setTheme(ThemeService.loveStory);

// Toggle
themeService.toggleTheme();
```

### Visual Preview:
- **Ghost**: Security icon, neon green gradient
- **Love**: Heart icon, pink/purple gradient

---

## 🔐 Biometric Setup

### Enable Biometrics:
```dart
final authenticated = await biometricService.authenticate(
  reason: 'Enable biometric authentication',
);
if (authenticated) {
  await biometricService.enableBiometrics();
}
```

### Check Status:
```dart
final enabled = await biometricService.isBiometricEnabled();
final available = await biometricService.isBiometricAvailable();
```

### Panic Wipe:
```dart
await biometricService.wipeAllSecureData();
```

---

## 🧪 Testing

### On Real Device:
1. Install APK on phone
2. Enable biometrics in system settings
3. Run app
4. Test fingerprint/face unlock

### On Emulator:
1. Android Emulator: Settings → Security → Fingerprint
2. Add fingerprint
3. Test authentication

---

## 🐛 Troubleshooting

### Pub Get Timeout
```bash
# Clear cache
flutter clean
flutter pub cache repair

# Try alternative mirror
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get
```

### Biometric Not Working
- Check device has fingerprint/face sensor
- Ensure lock screen is set (PIN/pattern)
- Add biometric in system settings

### Tor Not Connecting
- Check internet connection
- Verify TorService platform channel is implemented
- Check logs: `adb logcat | grep liberty`

---

## 📱 Build Commands

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

### Install on Device
```bash
flutter install
```

---

## 🎯 Next Steps

1. **Implement Main Chat Screen** - Replace placeholder
2. **Add Settings Navigation** - Button to open settings_screen.dart
3. **Platform Channels** - Implement TorService for Android/iOS
4. **Haptic Feedback** - Add vibration on theme toggle
5. **Sound Effects** - Optional audio cues

---

**Created:** March 17, 2026  
**Version:** 0.6.0 "Secure & Beautiful"  
**Status:** ✅ Code Complete, ⏳ Waiting for pub get
