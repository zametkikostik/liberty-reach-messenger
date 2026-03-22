# 🔐 CLOUD CONFIGURATION GUIDE

**Версия:** v0.16.1-cloud  
**Статус:** ✅ Готово к production

---

## 📋 Обзор

Приложение использует **две переменные** из облака (GitHub Secrets):

| Переменная | Назначение | Что происходит если не задана |
|------------|------------|-------------------------------|
| `ADMIN_MASTER_KEY` | Доступ к админ-панели | Админка заблокирована |
| `APP_MASTER_SALT` | Инициализация P2P-ноды | P2P работает с дефолтными параметрами |

---

## 🚀 Настройка GitHub Secrets

### 1. GitHub → Settings → Secrets and variables → Actions

### 2. Добавьте секреты:

```
Name: ADMIN_MASTER_KEY
Value: YourSecureRandomPassword2026!
```

```
Name: APP_MASTER_SALT
Value: YourRandomSaltForP2PInitialization
```

### 3. Рекомендуемые значения

```bash
# ADMIN_MASTER_KEY (минимум 16 символов)
openssl rand -base64 32

# APP_MASTER_SALT (любая случайная строка)
openssl rand -hex 32
```

---

## 🔐 Как это работает

### При старте приложения

```dart
// main.dart
void main() async {
  // 🔐 Чтение переменных из dart-define
  final adminKey = const String.fromEnvironment(
    'ADMIN_MASTER_KEY',
    defaultValue: 'NOT_SET',
  );
  
  final salt = const String.fromEnvironment(
    'APP_MASTER_SALT',
    defaultValue: 'NOT_SET',
  );
  
  // Инициализация CloudConfigService
  await CloudConfigService.instance.initialize(
    adminKey: adminKey,
    salt: salt,
  );
  
  runApp(...);
}
```

### Проверка в админке

```dart
// AdminAccessService
Future<bool> activateSovereignMode(String password) async {
  final cloudConfig = CloudConfigService.instance;
  
  // Если ADMIN_MASTER_KEY не установлен - блокировка
  if (!cloudConfig.isAdminKeySet) {
    return false; // Админка не работает
  }
  
  // Проверка пароля
  return cloudConfig.verifyAdminKey(password);
}
```

### Инициализация Rust

```dart
// RustBridgeService
Future<void> init({String? salt, bool isAdminMode = false}) async {
  // Передача соли в Rust-ядро через FFI
  await rust_lib.init(
    salt: salt,
    isAdminMode: isAdminMode,
  );
}
```

---

## 📊 Сценарии работы

### Сценарий 1: Обе переменные установлены ✅

```
ADMIN_MASTER_KEY: SET
APP_MASTER_SALT: SET

Результат:
✅ Приложение работает как мессенджер
✅ Админка доступна (7-tap + пароль)
✅ P2P-нода инициализирована с солью
✅ Все функции доступны
```

### Сценарий 2: Только ADMIN_MASTER_KEY ⚠️

```
ADMIN_MASTER_KEY: SET
APP_MASTER_SALT: NOT_SET

Результат:
✅ Приложение работает как мессенджер
✅ Админка доступна (7-tap + пароль)
⚠️ P2P-нода с дефолтными параметрами
✅ Все функции доступны
```

### Сценарий 3: Только APP_MASTER_SALT ⚠️

```
ADMIN_MASTER_KEY: NOT_SET
APP_MASTER_SALT: SET

Результат:
✅ Приложение работает как мессенджер
❌ Админка ЗАБЛОКИРОВАНА
✅ P2P-нода инициализирована с солью
⚠️ Админ-функции недоступны
```

### Сценарий 4: Ни одной переменной ❌

```
ADMIN_MASTER_KEY: NOT_SET
APP_MASTER_SALT: NOT_SET

Результат:
✅ Приложение работает как ОБЫЧНЫЙ мессенджер
❌ Админка ЗАБЛОКИРОВАНА
⚠️ P2P-нода с дефолтными параметрами
❌ Админ-функции недоступны
```

---

## 🛠️ Сборка

### GitHub Actions

```yaml
- name: Build Release APK
  run: |
    flutter build apk --release \
      --dart-define=ADMIN_MASTER_KEY=${{ secrets.ADMIN_MASTER_KEY }} \
      --dart-define=APP_MASTER_SALT=${{ secrets.APP_MASTER_SALT }}
```

### Локально

```bash
flutter build apk --release \
  --dart-define=ADMIN_MASTER_KEY=YourSecretKey \
  --dart-define=APP_MASTER_SALT=YourSaltValue
```

---

## 🧪 Проверка

### Логи при старте

```
[APP] START_DEBUG: 2026-03-22...
[CLOUD_CONFIG] ✅ CloudConfigService initialized
[CLOUD_CONFIG] ADMIN_MASTER_KEY: SET
[CLOUD_CONFIG] APP_MASTER_SALT: SET
[RUST_BRIDGE] 🔧 Initializing Rust Bridge with salt...
[RUST_BRIDGE] Salt: SET
[RUST_BRIDGE] Admin Mode: true
[RUST_BRIDGE] ✅ Rust Bridge initialized
```

### Если переменные не заданы

```
[CLOUD_CONFIG] ADMIN_MASTER_KEY: NOT_SET
[CLOUD_CONFIG] APP_MASTER_SALT: NOT_SET
[RUST_BRIDGE] Salt: NOT_SET
[RUST_BRIDGE] Admin Mode: false
```

---

## ⚠️ Безопасность

### НИКОГДА не делайте

❌ Не коммитьте секреты в код  
❌ Не логируйте значения переменных  
❌ Не передавайте через issue/PR  
❌ Не используйте дефолтные значения в production

### ВСЕГДА делайте

✅ Используйте GitHub Secrets  
✅ Генерируйте случайные значения  
✅ Проверяйте `isAdminKeySet` перед использованием  
✅ Очищайте память при выходе

---

## 📚 Файлы

- `cloud_config_service.dart` - центральный сервис
- `admin_access_service.dart` - проверка админ-пароля
- `rust_bridge_service.dart` - инициализация Rust
- `main.dart` - точка входа

---

**«Облачная конфигурация — безопасно и гибко!»** 🔐

*Liberty Reach Security Team*
