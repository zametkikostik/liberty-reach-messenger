#!/bin/bash
set -e

echo "🔥 BUILD APK v0.9.0 - Liberty Reach Sovereign"
echo "=============================================="
echo ""

# Переходим в директорию mobile
cd /home/kostik/Рабочий\ стол/папка\ для\ программирования/liberty-sovereign/mobile || exit 1

echo "📦 Шаг 1/6: Очистка..."
flutter clean
rm -rf android/build/
rm -rf android/app/build/
rm -rf android/.gradle/
rm -rf android/app/*.jks
rm -rf android/app/*.keystore
echo "✅ Очистка завершена"
echo ""

echo "📦 Шаг 2/6: Зависимости..."
flutter pub get
echo "✅ Зависимости установлены"
echo ""

echo "🔐 Шаг 3/6: Генерация keystore..."
cd android/app

keytool -genkey -v \
  -keystore release.jks \
  -alias liberty_sovereign \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass REDACTED_PASSWORD \
  -keypass REDACTED_PASSWORD \
  -dname "CN=Liberty Reach, OU=Sovereign Messenger, O=Freedom Project, L=Sofia, ST=Sofia, C=BG"

cd ../..
echo "✅ Keystore создан"
echo ""

echo "📝 Шаг 4/6: Создание key.properties..."
cat > android/key.properties << EOF
storePassword=REDACTED_PASSWORD
keyPassword=REDACTED_PASSWORD
keyAlias=liberty_sovereign
storeFile=release.jks
EOF
echo "✅ key.properties создан"
echo ""

echo "🏗️ Шаг 5/6: Сборка APK..."
flutter build apk --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=./build/symbols \
  --dart-define=MASTER_KEY=REDACTED_PASSWORD \
  --dart-define=BUILD_TYPE=release

echo ""
echo "✅ Шаг 6/6: Проверка..."
echo ""
echo "📱 APK файлы:"
ls -lh build/app/outputs/flutter-apk/
echo ""

echo "=============================================="
echo "🎉 СБОРКА ЗАВЕРШЕНА!"
echo "=============================================="
echo ""
echo "📍 APK находятся в:"
echo "   mobile/build/app/outputs/flutter-apk/"
echo ""
echo "📲 Для установки на телефон:"
echo "   adb install build/app/outputs/flutter-apk/app-release-arm64-v8a.apk"
echo ""
echo "🔐 Мастер-пароль: REDACTED_PASSWORD"
echo "✅ Keystore: android/app/release.jks"
echo ""
