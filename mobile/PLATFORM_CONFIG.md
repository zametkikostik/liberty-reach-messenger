# 📱 Platform Configuration Guide

## Android Configuration ✅

### AndroidManifest.xml
Already configured with:
- ✅ Internet permissions
- ✅ Foreground service for Tor
- ✅ Camera, Microphone for WebRTC
- ✅ Bluetooth for P2P
- ✅ Storage for backups

### build.gradle
Already configured with:
- ✅ `minSdk 26` (required for Tor)
- ✅ Tor Android binary dependency
- ✅ MultiDex support
- ✅ Signing config

### Additional Setup for Biometrics

No additional setup needed! The `local_auth` package works out of the box with Android.

---

## iOS Configuration 🍎

### Step 1: Create iOS Folder
If you haven't created iOS platform folder yet:

```bash
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile
flutter create --platforms=ios .
```

### Step 2: Update Info.plist

Add these keys to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Liberty Reach uses Face ID to secure your messages</string>

<key>NSCameraUsageDescription</key>
<string>Camera is used for QR code scanning</string>

<key>NSMicrophoneUsageDescription</key>
<string>Microphone is used for voice calls via WebRTC</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used for local P2P communication</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required for P2P messaging</string>
```

### Step 3: Update Podfile

In `ios/Podfile`, ensure minimum iOS version is 12.0:

```ruby
platform :ios, '12.0'

# Enable static frameworks for some plugins
installer.pods_project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
  end
end
```

Then run:
```bash
cd ios
pod install
cd ..
```

### Step 4: Update Capabilities in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to "Signing & Capabilities"
3. Add:
   - **Face ID** (for biometrics)
   - **Background Modes** → **Audio** (for WebRTC calls)

---

## Verification Checklist

### Android
- [ ] Run `flutter doctor`
- [ ] Check Android Studio SDK
- [ ] Test on physical device (biometrics require real hardware)

### iOS
- [ ] Run `flutter doctor`
- [ ] Check Xcode installation
- [ ] Test on physical device (simulator doesn't support Face ID)

---

## Testing Biometrics

### Android Emulator Setup
1. Open Android Emulator
2. Go to Settings → Security → Fingerprint
3. Add a fingerprint
4. Your app can now test biometrics

### iOS Simulator Setup
1. Open Simulator
2. Go to Settings → Face ID & Passcode
3. Enable Face ID
4. Test with "Matching" or "Non-Matching" face in simulator

---

## Troubleshooting

### Android: Biometrics Not Available
```
Problem: isBiometricAvailable() returns false

Solution:
1. Check device has fingerprint/face sensor
2. Ensure lock screen is set (PIN/pattern)
3. Add at least one fingerprint in Settings
```

### iOS: Face ID Permission Denied
```
Problem: User denied Face ID permission

Solution:
1. Go to Settings → Liberty Reach
2. Enable Face ID permission
3. Restart app
```

### Pub Get Timeout
```bash
# Try alternative mirror
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get

# Or use cache
flutter pub cache repair
flutter clean
flutter pub get
```

---

## Build Commands

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA (requires Mac)
```bash
flutter build ios --release
# Then archive in Xcode
```

---

**Last Updated:** March 17, 2026
**Version:** 0.6.0
