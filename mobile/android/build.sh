#!/bin/bash
# Android Build Script for Liberty Reach

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     🦅 Liberty Reach - Android Build                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check for Android SDK
if [ -z "$ANDROID_HOME" ]; then
    echo "[!] ANDROID_HOME not set. Please set it to your Android SDK path"
    echo "    Example: export ANDROID_HOME=~/Android/Sdk"
    exit 1
fi

echo "[*] Android SDK: $ANDROID_HOME"
echo "[*] NDK: $ANDROID_NDK_HOME"

# Navigate to Android project
cd mobile/android

# Build debug APK
echo "[*] Building debug APK..."
./gradlew assembleDebug

# Build release APK (requires signing)
echo "[*] Building release APK..."
./gradlew assembleRelease

echo ""
echo "✓ Build complete!"
echo "  Debug:   app/build/outputs/apk/debug/app-debug.apk"
echo "  Release: app/build/outputs/apk/release/app-release.apk"
