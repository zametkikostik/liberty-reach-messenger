# 🔧 APK FIX: "Пакет недействителен" / "Package is invalid"

**Проблема:** При установке APK появляется ошибка "Пакет недействителен" или "App not installed"  
**Решение:** ✅ Исправлено в v0.16.1-cloud

---

## ❌ ПРИЧИНЫ ПРОБЛЕМЫ

### 1. APK не подписан
```
jar is unsigned.
```

**Решение:** Пересобрать с правильной подписью ✅

### 2. Неправильная подпись
```
keystore password was incorrect
```

**Решение:** Использовать правильный keystore ✅

### 3. Конфликт версий
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE
```

**Решение:** Удалить старую версию перед установкой

---

## ✅ ИСПРАВЛЕНИЯ В v0.16.1-cloud

### 1. Новый Keystore

```
Keystore: mobile/android/app/release.jks
Alias: liberty
Password: liberty123
```

### 2. Правильная подпись

APK автоматически подписывается Gradle при сборке:

```bash
flutter build apk --release --split-per-abi
```

### 3. Split APKs

Теперь собираем 3 APK для разных архитектур:

| APK | Размер | Устройство |
|-----|--------|------------|
| `app-arm64-v8a-release.apk` | 40.5 MB | Современные (64-bit) |
| `app-armeabi-v7a-release.apk` | 32.8 MB | Старые (32-bit) |
| `app-x86_64-release.apk` | 43 MB | Эмуляторы |

---

## 📲 УСТАНОВКА

### Шаг 1: Выберите правильный APK

**Для большинства устройств:**
```
app-arm64-v8a-release.apk (40.5 MB)
```

**Для старых устройств:**
```
app-armeabi-v7a-release.apk (32.8 MB)
```

### Шаг 2: Удалите старую версию (если есть)

```
Настройки → Приложения → Liberty Reach → Удалить
```

### Шаг 3: Разрешите установку

**Android 8+:**
```
Настройки → Приложения → [Браузер/Файловый менеджер] → 
Разрешить установку неизвестных приложений
```

**Android 7 и ниже:**
```
Настройки → Безопасность → Неизвестные источники → Включить
```

### Шаг 4: Установите APK

1. Откройте файловый менеджер
2. Найдите APK
3. Нажмите "Установить"
4. Дождитесь завершения

---

## 🆘 ЕСЛИ ВСЁ ЕЩЁ НЕ РАБОТАЕТ

### Ошибка: "App not installed"

**Причина:** Конфликт подписей  
**Решение:**
```bash
# 1. Удалите старую версию
adb uninstall com.example.liberty_reach

# 2. Установите новую
adb install app-arm64-v8a-release.apk
```

### Ошибка: "Parse error"

**Причина:** Повреждённый APK  
**Решение:**
- Скачайте APK заново
- Проверьте размер файла (должен быть ~40 MB)

### Ошибка: "Package is invalid"

**Причина:** Неправильная архитектура  
**Решение:**
- Попробуйте `app-armeabi-v7a-release.apk` (32-bit)
- Или `app-x86_64-release.apk` (для эмуляторов)

---

## 🔍 ПРОВЕРКА APK

### Проверка подписи

```bash
# Через apksigner
apksigner verify --verbose app-arm64-v8a-release.apk

# Ожидается:
# Verified using v1 scheme (JAR signing): true
# Verified using v2 scheme: true
```

### Проверка содержимого

```bash
# Через unzip
unzip -l app-arm64-v8a-release.apk | head -20
```

---

## 📊 СРАВНЕНИЕ ВЕРСИЙ

| Версия | Подпись | Проблема | Статус |
|--------|---------|----------|--------|
| v0.16.0 | ❌ Не подписан | "Package is invalid" | ❌ Не работает |
| v0.16.1-cloud | ✅ Подписан | Нет | ✅ Работает |

---

## ✅ ЧЕК-ЛИСТ

- [x] Keystore создан (liberty)
- [x] key.properties настроен
- [x] build.gradle подписывает APK
- [x] APK собран с --split-per-abi
- [x] Подпись проверена Gradle

---

## 📚 СВЯЗАННАЯ ДОКУМЕНТАЦИЯ

- [APK_READY.md](APK_READY.md) — инструкция по загрузке
- [APK_BUILD_INSTRUCTIONS.md](APK_BUILD_INSTRUCTIONS.md) — сборка APK
- [BUILD_FIX.md](BUILD_FIX.md) — исправление ошибок сборки

---

**«APK теперь подписан и готов к установке!»** 🚀

*Liberty Reach Build Team*  
*22 марта 2026 г.*
