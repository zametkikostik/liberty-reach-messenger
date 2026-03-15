#!/bin/bash

# Liberty Reach - Android Build Setup Script
# Помощник для настройки GitHub Actions secrets

echo "🏰 Liberty Reach - Android Build Setup"
echo "======================================="
echo ""

# Проверка что мы в правильной директории
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found!"
    echo "Please run this script from the Flutter project root (mobile/ directory)"
    exit 1
fi

echo "✅ Found pubspec.yaml"
echo ""

# 1. Проверка keystore
KEYSTORE_PATH="android/app/upload-keystore.jks"
if [ -f "$KEYSTORE_PATH" ]; then
    echo "✅ Found keystore: $KEYSTORE_PATH"
    
    # Кодируем keystore в base64
    echo "📦 Encoding keystore to base64..."
    KEYSTORE_BASE64=$(base64 -w 0 "$KEYSTORE_PATH")
    echo "✅ Keystore encoded (${#KEYSTORE_BASE64} characters)"
    echo ""
    echo "🔐 Add this to GitHub Secrets as KEYSTORE_BASE64:"
    echo "----------------------------------------------------------------"
    echo "$KEYSTORE_BASE64"
    echo "----------------------------------------------------------------"
    echo ""
else
    echo "⚠️  Keystore not found at: $KEYSTORE_PATH"
    echo ""
    echo "📝 To create a keystore, run:"
    echo "keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
    echo ""
fi

# 2. Проверка key.properties
KEY_PROPS="android/key.properties"
if [ -f "$KEY_PROPS" ]; then
    echo "✅ Found key.properties"
    echo ""
    echo "📋 Current key.properties content:"
    echo "----------------------------------------------------------------"
    cat "$KEY_PROPS"
    echo "----------------------------------------------------------------"
    echo ""
else
    echo "⚠️  key.properties not found"
    echo ""
fi

# 3. Инструкции для GitHub Secrets
echo "🔐 GITHUB SECRETS SETUP"
echo "======================="
echo ""
echo "Go to: https://github.com/zametkikostik/liberty-reach-messenger/settings/secrets/actions"
echo ""
echo "Add these secrets:"
echo ""
echo "1. KEYSTORE_BASE64"
echo "   - Copy the base64 string above"
echo "   - Or run: cat android/app/upload-keystore.jks | base64 | pbcopy"
echo ""
echo "2. KEYSTORE_PASSWORD"
echo "   - Your keystore password"
echo ""
echo "3. KEY_PASSWORD"
echo "   - Your key password"
echo ""
echo "4. KEY_ALIAS"
echo "   - Your key alias (default: upload)"
echo ""
echo "5. GITHUB_TOKEN (automatic)"
echo "   - Created automatically by GitHub"
echo ""

# 4. Тестовый запуск
echo "🧪 TEST BUILD"
echo "============="
echo ""
echo "To test locally before pushing:"
echo ""
echo "flutter clean"
echo "flutter pub get"
echo "flutter build apk --release"
echo ""
echo "APK will be at: build/app/outputs/flutter-apk/app-release.apk"
echo ""

echo "✅ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "1. Add secrets to GitHub"
echo "2. Push code to GitHub"
echo "3. Create a tag: git tag v0.4.0-fortress-stable"
echo "4. Push tag: git push origin v0.4.0-fortress-stable"
echo "5. GitHub Actions will build APK automatically!"
echo ""
