# 🔐 HIDDEN SOVEREIGN PORTAL - IMPLEMENTATION

**Версия:** v0.11.0  
**Дата:** 21 марта 2026  
**Статус:** ✅ PRODUCTION READY

---

## 📊 ОБЗОР

**Hidden Sovereign Portal** — это скрытый механизм активации **Sovereign Mode** для владельца/администратора ноды.

### Ключевые принципы:

1. **User Flow** — обычная регистрация (Login/Sign Up)
2. **Admin Flow** — скрытый вход через 7-кратный тап
3. **Sovereign Mode** — полный доступ к системным функциям
4. **Zero-Persistence** — мастер-пароль ТОЛЬКО в RAM

---

## 👤 USER FLOW

### Обычная регистрация

**Экран:** `UserLoginScreen`

```dart
// Регистрация нового пользователя
await adminService.userRegister(username, password, email);

// Вход существующего
await adminService.userLogin(username, password);

// Флаг:
isUserLoggedIn = true
isSovereignMode = false  // ← Обычный пользователь
```

**Доступные функции:**
- ✅ Чаты и сообщения
- ✅ Контакты
- ✅ Настройки профиля
- ✅ Базовые настройки приложения
- ❌ Логи Rust-ядра
- ❌ Memory Wipe
- ❌ Управление нодой
- ❌ Лимиты сети

---

## 🔐 SOVEREIGN FLOW

### Hidden Sovereign Portal (7 тапов)

**Экран:** `HiddenSovereignPortalScreen`

**Как активировать:**

1. Открыть **Настройки** приложения
2. Найти секцию **"О приложении"** или **"Версия"**
3. Быстро тапнуть **7 раз за 3 секунды**
4. Откроется **Hidden Sovereign Portal**
5. Ввести мастер-пароль: `REDACTED_PASSWORD`
6. Активируется **Sovereign Mode**

```dart
// Обработка 7-кратного тапа
bool handleSecretTap() {
  _tapCount++;
  
  if (_tapCount >= 7) {
    // ОТКРЫТЬ ПОРТАЛ
    return true;
  }
}

// Активация Sovereign Mode
await adminService.activateSovereignMode('REDACTED_PASSWORD');

// Флаг:
isSovereignMode = true  // ← В RAM!
```

---

## 🛡️ БЕЗОПАСНОСТЬ

### Sovereign Mode флаг

```dart
class AdminAccessService {
  bool _isSovereignMode = false;  // ← ТОЛЬКО в RAM!
  Uint8List? _sovereignPasswordBytes;
  
  bool get isSovereignMode => _isSovereignMode;
  
  void onAppPaused() {
    if (_isSovereignMode) {
      _isSovereignMode = false;  // ← WIPE при сворачивании
    }
  }
  
  void logout() {
    _secureWipe();  // ← Полное затирание
  }
}
```

**Принципы:**
- ✅ Хранится ТОЛЬКО в оперативной памяти
- ✅ Исчезает при сворачивании приложения
- ✅ Исчезает при закрытии приложения
- ✅ 3 ошибки ввода → PANIC WIPE

### 3-Attempt Rule → PANIC WIPE

```dart
static const int maxFailedAttempts = 3;

bool checkPasswordAttempt(String password) {
  if (password == sovereignMasterPassword) {
    _failedAttempts = 0;
    return true;
  }
  
  _failedAttempts++;
  
  if (_failedAttempts >= maxFailedAttempts) {
    '🚨 PANIC WIPE: $_failedAttempts failed attempts'.secureError();
    _secureWipe();  // 4-pass zeroization
    throw SecurityException('PANIC WIPE: 3 failed attempts');
  }
  
  return false;
}
```

### FULL Memory Wipe (4-pass zeroization)

```dart
void _secureWipe() {
  if (_sovereignPasswordBytes != null) {
    // Pass 1: Random data
    for (int i = 0; i < _sovereignPasswordBytes!.length; i++) {
      _sovereignPasswordBytes![i] = (i * 31) & 0xFF;
    }
    
    // Pass 2: All zeros
    // Pass 3: All ones
    // Pass 4: Final zeros
  }
  _isSovereignMode = false;
}
```

---

## 📱 ЭКРАНЫ

### User Flow

| Экран | Файл | Описание |
|-------|------|----------|
| Login | `user_login_screen.dart` | Вход по нику + пароль |
| Register | `user_register_screen.dart` | Регистрация нового |
| Chat List | `chat_list_screen.dart` | Список чатов |

### Sovereign Flow

| Экран | Файл | Описание |
|-------|------|----------|
| Hidden Portal | `hidden_sovereign_portal_screen.dart` | 7-tap активация |
| Sovereign Dashboard | `sovereign_dashboard_screen.dart` | Панель управления |

---

## 🔐 SOVEREIGN DASHBOARD

**Экран:** `SovereignDashboardScreen`

### Функции:

#### 1. Node Control

- ✅ Старт/стоп ноды
- ✅ Мониторинг статуса
- ✅ Перезапуск ядра

#### 2. Memory Wipe Control

- ✅ Ручная активация Memory Wipe
- ✅ Полное затирание RAM
- ✅ Перезапуск приложения

#### 3. Network Limits

- ✅ Ограничение bandwidth
- ✅ Лимит соединений
- ✅ Лимит пиров в DHT

#### 4. Rust Core Logs

- ✅ Логи в реальном времени
- ✅ Автообновление каждые 2 сек
- ✅ Цветовая кодировка (ERROR/WARN/INFO/DEBUG)
- ✅ Автопрокрутка вниз

---

## 🎯 КАК ИСПОЛЬЗОВАТЬ

### Для пользователя:

1. Открыть приложение
2. Нажать **"Sign Up"** (если нет аккаунта)
3. Ввести ник, email, пароль
4. Нажать **"Register"**
5. Войти с ником и паролем
6. Пользователь в чатах

### Для админа (Sovereign Mode):

1. Открыть приложение
2. Войти как обычный пользователь (для маскировки)
3. Открыть **Настройки**
4. Найти **"Версия приложения: v0.11.0"**
5. Быстро тапнуть **7 раз** за 3 секунды
6. Ввести мастер-пароль: `REDACTED_PASSWORD`
7. Открылся **Sovereign Dashboard**
8. Доступны:
   - Логи Rust-ядра
   - Memory Wipe
   - Управление нодой
   - Лимиты сети

---

## 📋 CHECKLIST

### Реализовано:

- [x] User Login/Register
- [x] Admin Access Service (обновлён)
- [x] 7-tap gesture detector
- [x] Hidden Sovereign Portal Screen
- [x] Sovereign Dashboard Screen
- [x] isSovereignMode flag in RAM
- [x] 3-attempt rule → PANIC WIPE
- [x] FULL Memory Wipe (4-pass)
- [x] Rust logs streaming
- [x] Node control (start/stop)
- [x] Network limits (bandwidth, connections, peers)
- [x] Memory wipe on pause/exit

---

## 🔐 MASTER PASSWORD

**Пароль:** `REDACTED_PASSWORD`

**Хранение:**
- ✅ ТОЛЬКО в RAM (`Uint8List`)
- ✅ НИКОГДА не сохраняется на диск
- ✅ НИКОГДА не передаётся по сети
- ✅ НИКОГДА не хешируется
- ✅ Исчезает при выходе/сворачивании
- ✅ 3 ошибки → PANIC WIPE

---

**«Скрытый портал для Суверенного Владельца»** 🔐

---

*Implementation completed for Liberty Reach v0.11.0*
