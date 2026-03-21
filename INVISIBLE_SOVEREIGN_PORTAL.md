# 🔐 INVISIBLE SOVEREIGN PORTAL - UI IMPLEMENTATION

**Версия:** v0.12.0  
**Статус:** ✅ PRODUCTION READY

---

## 📊 ОБЗОР

**Invisible Sovereign Portal** — скрытый UI механизм активации **Sovereign Mode** через 7-кратный тап на версию приложения в настройках.

---

## 🎯 ЛОКАЦИЯ

**Где:** Settings Screen → раздел "About"  
**Что:** Text виджет с версией приложения  
**Как:** GestureDetector на 7 тапов за 3 секунды

---

## 🔐 МЕХАНИЗМ АКТИВАЦИИ

### 1. 7-Tap Gesture
- Тапнуть 7 раз на версию за 3 секунды
- Открывается System Verification Dialog

### 2. System Verification Dialog
- Заголовок: "System Verification"
- Поле: TextField (obscureText: true)
- Кнопки: Cancel / Verify

### 3. Валидация пароля
- Мастер-пароль: `REDACTED_PASSWORD`
- 3 попытки → PANIC WIPE

### 4. Последствие
- Admin Console пункт в Drawer
- Исчезает при закрытии приложения (RAM Wipe)

---

## 🛡️ БЕЗОПАСНОСТЬ

- ✅ Zero-Persistence (только RAM)
- ✅ 3-Attempt Rule → PANIC WIPE
- ✅ FULL Memory Wipe (4-pass)
- ✅ Admin Console исчезает при выходе

---

## 🎯 КАК ИСПОЛЬЗОВАТЬ

1. Settings → About
2. 7 тапов на версию
3. Ввести: `REDACTED_PASSWORD`
4. Sovereign Dashboard открыт
5. В Drawer появился "Admin Console"

---

**«Невидимый портал для Суверенного Владельца»** 🔐

*Liberty Reach v0.12.0*
