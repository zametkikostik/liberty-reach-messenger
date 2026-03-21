# 🔐 USER vs SOVEREIGN ADMIN - ARCHITECTURE

**Версия:** v0.10.0  
**Дата:** 21 марта 2026  
**Статус:** ✅ IMPLEMENTED

---

## 📊 ОБЗОР АРХИТЕКТУРЫ

Приложение разделено на **два независимых потока**:

```
┌─────────────────────────────────────────────────────────┐
│                  LIBERTY REACH APP                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────┐    ┌────────────────────┐      │
│  │   USER FLOW        │    │  SOVEREIGN FLOW    │      │
│  │                    │    │                    │      │
│  │  - Registration    │    │  - 5-tap gesture   │      │
│  │  - Username/Pass   │    │  - Master Password │      │
│  │  - Chat access     │    │  - isAdmin = true  │      │
│  │  - No system logs  │    │  - Rust logs       │      │
│  │                    │    │  - Node control    │      │
│  └────────────────────┘    └────────────────────┘      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 👤 USER FLOW

### Обычная регистрация

**Экран:** `UserLoginScreen`

```dart
// Вход пользователя
await adminService.userLogin(username, password);

// Флаг:
isUserLoggedIn = true
isAdmin = false
```

**Доступ:**
- ✅ Чаты
- ✅ Сообщения
- ✅ Контакты
- ✅ Настройки профиля
- ❌ Логи Rust-ядра
- ❌ Управление нодой
- ❌ Системные настройки

**Хранение:**
- Локальная БД (SQLite)
- SharedPreferences для сессии

---

## 🔐 SOVEREIGN ADMIN FLOW

### Скрытый вход (5 тапов)

**Экран:** `SecretAdminLoginScreen`

**Как активировать:**
1. Открыть **Настройки**
2. Найти **"Версия приложения: v0.10.0"**
3. Быстро тапнуть **5 раз за 2 секунды**
4. Откроется окно ввода мастер-пароля
5. Ввести: `REDACTED_PASSWORD`

```dart
// Обработка 5-кратного тапа
bool handleSecretTap() {
  _tapCount++;
  
  if (_tapCount >= 5) {
    // Показать окно ввода пароля
    return true;
  }
}

// Проверка мастер-пароля
await adminService.adminLogin('REDACTED_PASSWORD');

// Флаг:
isAdmin = true  // ← В RAM!
```

**Доступ:**
- ✅ Всё из USER FLOW
- ✅ **Логи Rust-ядра (libp2p)** в реальном времени
- ✅ **Управление нодой** (старт/стоп/рестарт)
- ✅ **P2P статистика** (пиры, DHT, соединения)
- ✅ **Системные настройки**
- ✅ **Конфигурация bootstrap peers**

---

## 🛡️ БЕЗОПАСНОСТЬ

### isAdmin флаг

```dart
class AdminAccessService {
  bool _isAdmin = false;  // ← ТОЛЬКО в RAM!
  
  bool get isAdmin => _isAdmin;
  
  void onAppPaused() {
    if (_isAdmin) {
      _isAdmin = false;  // ← WIPE при сворачивании
    }
  }
  
  void logout() {
    _isAdmin = false;  // ← WIPE при выходе
  }
}
```

**Принципы:**
- ✅ Хранится ТОЛЬКО в оперативной памяти
- ✅ Исчезает при сворачивании приложения
- ✅ Исчезает при закрытии приложения
- ✅ 3 ошибки ввода → PANIC WIPE

### 3 Attempt Rule

```dart
static const int maxFailedAttempts = 3;

if (_failedAttempts >= maxFailedAttempts) {
  // 🔥 PANIC WIPE ACTIVATED
  adminService.logout();
  Navigator.of(context).pop(); // Закрыть окно
}
```

---

## 📱 ЭКРАНЫ

### User Flow

| Экран | Файл | Описание |
|-------|------|----------|
| Login | `user_login_screen.dart` | Вход по нику + пароль |
| Chat List | `chat_list_screen.dart` | Список чатов |
| Chat Room | `chat_room_screen.dart` | Комната чата |

### Sovereign Flow

| Экран | Файл | Описание |
|-------|------|----------|
| Secret Login | `secret_admin_login_screen.dart` | Скрытый ввод (5 тапов) |
| Admin Dashboard | `admin_dashboard_screen.dart` | Логи Rust + управление |

---

## 🔐 ADMIN DASHBOARD

### Логи Rust-ядра

**Экран:** `AdminDashboardScreen`

```
┌────────────────────────────────────────┐
│  🔐 Sovereign Admin                    │
├────────────────────────────────────────┤
│  [D] Rust libp2p Node                  │
│      Status: Running                   │
│      [Stop Button]                     │
├────────────────────────────────────────┤
│  📟 Rust Core Logs (libp2p)            │
│  ┌──────────────────────────────────┐  │
│  │ [12:34:56] [libp2p] Peer disc... │  │
│  │ [12:34:58] [DHT] Routing tabl... │  │
│  │ [12:35:00] [Noise] Handshake...  │  │
│  │ [12:35:02] [Yamux] New stream... │  │
│  │ [12:35:04] [Gossipsub] Message...│  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Функции:**
- ✅ Логи в реальном времени (автообновление каждые 2 сек)
- ✅ Автопрокрутка вниз
- ✅ Цветовая кодировка (ERROR/WARN/INFO/DEBUG)
- ✅ Кнопка старт/стоп ноды
- ✅ Кнопка logout (выход из режима админа)

---

## 🎯 КАК ИСПОЛЬЗОВАТЬ

### Для пользователя:

1. Открыть приложение
2. Ввести ник и пароль
3. Нажать "Войти"
4. Пользователь в чатах

### Для админа:

1. Открыть приложение
2. Войти как обычный пользователь (для маскировки)
3. Открыть **Настройки**
4. Быстро тапнуть **5 раз** на "Версия приложения"
5. Ввести мастер-пароль: `REDACTED_PASSWORD`
6. Открылся **Admin Dashboard**

---

## 📋 CHECKLIST

### Реализовано:

- [x] User Login Screen
- [x] Admin Access Service
- [x] 5-tap gesture detector
- [x] Secret Admin Login Screen
- [x] Admin Dashboard
- [x] Rust logs streaming
- [x] Node control (start/stop)
- [x] isAdmin flag in RAM
- [x] 3-attempt rule → PANIC WIPE
- [x] Memory wipe on pause/exit

---

## 🚀 ССЫЛКИ

- [Admin Access Service](mobile/lib/services/admin_access_service.dart)
- [User Login Screen](mobile/lib/screens/user_login_screen.dart)
- [Secret Admin Login](mobile/lib/screens/secret_admin_login_screen.dart)
- [Admin Dashboard](mobile/lib/screens/admin_dashboard_screen.dart)
- [Sovereign Manifesto](SOVEREIGN_MASTER_PASSWORD_MANIFESTO.md)

---

**«Два лица Liberty: Пользователь и Суверен»** 🔐

---

*Implementation completed for Liberty Reach v0.10.0*
