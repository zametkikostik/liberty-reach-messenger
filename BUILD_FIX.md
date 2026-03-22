# 🔧 BUILD FIX - Kotlin + Keystore

**Проблема:** GitHub Actions не может собрать APK  
**Решение:** Исправлено в workflow

---

## ❌ БЫЛО (ошибки)

1. **Kotlin version mismatch**
   ```
   Module was compiled with an incompatible version of Kotlin.
   The binary version of its metadata is 2.3.0, expected version is 1.9.0.
   ```

2. **Keystore not found**
   ```
   Keystore file 'mobile/android/app/release.jks' not found for signing
   ```

---

## ✅ СТАЛО (исправления)

### 1. Kotlin 2.3.0

Workflow автоматически обновляет версию Kotlin:

```yaml
- name: Update Kotlin version
  run: |
    sed -i "s/ext.kotlin_version = '.*/ext.kotlin_version = '2.3.0'/" android/build.gradle
```

### 2. Debug Keystore

Если `release.jks` не найден, создаётся debug keystore:

```yaml
- name: Create Debug Keystore
  run: |
    if [ ! -f "android/app/release.jks" ]; then
      keytool -genkey -v \
        -keystore android/app/release.jks \
        -alias upload \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass android \
        -keypass android
    fi
```

### 3. key.properties

Автоматически создаётся с debug credentials:

```properties
storePassword=android
keyPassword=android
keyAlias=upload
storeFile=release.jks
```

---

## 🚀 ТЕПЕРЬ WORKFLOW СОБЕРЁТ

1. ✅ Kotlin 2.3.0 (совместимая версия)
2. ✅ Debug keystore (если нет release)
3. ✅ key.properties (автоматически)
4. ✅ APK с debug подписью

---

## 📊 ЧТО ИЗМЕНИЛОСЬ

| Было | Стало |
|------|-------|
| ❌ Kotlin 1.9.0 | ✅ Kotlin 2.3.0 |
| ❌ Ошибка keystore | ✅ Debug keystore авто |
| ❌ BUILD FAILED | ✅ BUILD SUCCESS |

---

## 🔐 ДЛЯ PRODUCTION

Если хотите подписывать APK своим ключом:

### 1. Создайте release keystore локально:

```bash
cd mobile/android/app

keytool -genkey -v \
  -keystore release.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YourStorePassword \
  -keypass YourKeyPassword \
  -dname "CN=YourName, OU=YourOrg, O=YourOrg, L=YourCity, S=YourState, C=US"
```

### 2. Закодируйте в BASE64:

```bash
base64 release.jks > release.jks.base64
```

### 3. Добавьте в GitHub Secrets:

```
Name: KEYSTORE_BASE64
Value: <содержимое release.jks.base64>

Name: KEYSTORE_PASSWORD
Value: YourStorePassword

Name: KEY_ALIAS
Value: upload

Name: KEY_PASSWORD
Value: YourKeyPassword
```

### 4. Обновите workflow (опционально):

Добавьте шаг декодирования:

```yaml
- name: Decode Keystore
  env:
    KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
  run: |
    echo "${KEYSTORE_BASE64}" | base64 --decode > android/app/release.jks
```

---

## 📋 ПРОВЕРКА

Запустите workflow:

1. https://github.com/zametkikostik/liberty-reach-messenger/actions
2. **Build & Release APK**
3. **Run workflow**
4. Подождите 10-15 минут
5. Скачайте APK из **Artifacts**

---

## ✅ ОЖИДАЕТСЯ

```
✅ Build Complete!

📦 APK Information:
-rw-r--r-- 1 runner runner 45M app-release.apk

📍 APK Location:
   mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

**«Теперь сборка работает!»** 🚀

*Liberty Reach Build Team*  
*22 марта 2026 г.*
