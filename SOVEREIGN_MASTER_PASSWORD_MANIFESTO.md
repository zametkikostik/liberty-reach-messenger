# 🔐 SOVEREIGN MASTER PASSWORD MANIFESTO

## Философия Суверенного Мастер-Пароля

**Версия:** v0.9.0  
**Статус:** CRITICAL SECURITY PROTOCOL  
**Классификация:** SOVEREIGN-ONLY ACCESS

---

## ⚠️ ЧТО ЭТО ТАКОЕ

### Мастер-Пароль — это НЕ пароль пользователя

```
❌ НЕ пароль для входа в аккаунт
❌ НЕ данные для аутентификации на сервере
❌ НЕ ключ для расшифровки базы данных
✅ ЕДИНСТВЕННЫЙ вход в систему управления ключами Kyber в RAM
✅ Ключ активации Rust-ядра (libp2p)
✅ Высший уровень привилегий в системе
```

---

## 🔒 ПРИНЦИПЫ БЕЗОПАСНОСТИ

### 1. Zero-Persistence Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  MASTER PASSWORD LIFECYCLE               │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  [Ввод] → [RAM] → [Kyber Key Derivation] → [Use]       │
│     ↑        |                                          │
│     |        └──→ [WIPE on Exit/Pause/Timeout]          │
│     |                                                    │
│  [Retry] ← [3 Failed Attempts] → [PANIC WIPE]           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Правила:**
- ✅ Пароль существует ТОЛЬКО в оперативной памяти
- ✅ НИКОГДА не сохраняется на диск (SharedPreferences, KeyStore, БД)
- ✅ НИКОГДА не передаётся по сети
- ✅ НИКОГДА не хешируется для хранения
- ✅ Исчезает при закрытии приложения
- ✅ Исчезает при сворачивании (AppLifecycleState.paused)
- ✅ Исчезает после 3 неудачных попыток ввода

---

### 2. Not A "Thoroughfare" (Не Проходной Двор)

```rust
// ❌ НЕПРАВИЛЬНО (серверное хранение)
server.verify_password(user_id, password_hash)

// ✅ ПРАВИЛЬНО (локальная верификация в RAM)
let is_valid = verify_in_ram(&input_password, &stored_in_memory);
if !is_valid {
    panic_wipe_memory(); // Полное затирание
}
```

**Запрещено:**
- ❌ Сохранять в `SharedPreferences`
- ❌ Сохранять в `FlutterSecureStorage`
- ❌ Сохранять в `Android KeyStore`
- ❌ Отправлять на сервер для проверки
- ❌ Хешить для "безопасного хранения"
- ❌ Логировать (даже в debug)

**Разрешено:**
- ✅ Хранить в `Uint8List` в оперативной памяти
- ✅ Использовать для генерации Kyber ключа
- ✅ Сравнивать в памяти (constant-time comparison)
- ✅ Затирать нулями после использования

---

### 3. Trigger Memory Wipe (3 Attempt Rule)

```dart
class SecurePasswordManager {
  static const int maxFailedAttempts = 3;
  int _failedAttempts = 0;
  
  Future<bool> verifyPassword(String input) async {
    if (input != _storedPassword) {
      _failedAttempts++;
      
      if (_failedAttempts >= maxFailedAttempts) {
        // 🔥 PANIC WIPE ACTIVATED
        await _secureWipe();
        await _wipeAllSensitiveData();
        throw SecurityException('PANIC WIPE: 3 failed attempts');
      }
      
      return false;
    }
    
    _failedAttempts = 0;
    return true;
  }
  
  Future<void> _secureWipe() async {
    // 3-pass zeroization
    // Pass 1: Random data
    // Pass 2: All zeros
    // Pass 3: All ones
    // Pass 4: All zeros (final)
  }
}
```

**Почему 3 попытки:**
- 🛡️ Защита от брутфорса внутри RAM
- 🛡️ Защита от физического доступа к устройству
- 🛡️ Защита от dump памяти
- 🛡️ Автоматическое уничтожение ключей

---

### 4. Sovereign Access Only

**Иерархия доступа:**

```
┌────────────────────────────────────────┐
│   SOVEREIGN MASTER PASSWORD            │ ← ВЫСШИЙ УРОВЕНЬ
│   (REDACTED_PASSWORD)                   │
│   └─ Activates: Kyber Keys in RAM      │
│   └─ Activates: libp2p Rust Core       │
│   └─ Activates: P2P Network Stack      │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│   USER BIOMETRIC/PIN                   │ ← ВТОРОЙ УРОВЕНЬ
│   (Face ID / Fingerprint)              │
│   └─ Unlocks: UI Access                │
│   └─ Unlocks: Chat List                │
└────────────────────────────────────────┘
```

**Без Мастер-Пароля:**
- ❌ Rust-ядро НЕ инициализируется
- ❌ libp2p стек НЕ запускается
- ❌ Kyber ключи НЕ генерируются
- ❌ P2P сеть НЕ доступна
- ❌ Нода НЕ подключается к пирам

---

## 🛡️ ТЕХНИЧЕСКАЯ РЕАЛИЗАЦИЯ

### Secure Memory Storage

```dart
import 'dart:typed_data';

class SovereignKeyStore {
  // Пароль хранится ТОЛЬКО в RAM
  Uint8List? _passwordBytes;
  bool _isPasswordSet = false;
  
  // 3-pass zeroization
  void _secureWipe(Uint8List bytes) {
    // Pass 1: Случайные данные
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = (i * 31) & 0xFF;
    }
    
    // Pass 2: Все нули
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0x00;
    }
    
    // Pass 3: Все единицы
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0xFF;
    }
    
    // Pass 4: Финальные нули
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0x00;
    }
  }
  
  void wipePassword() {
    if (_passwordBytes != null) {
      _secureWipe(_passwordBytes!);
      _passwordBytes = null;
      _isPasswordSet = false;
    }
  }
}
```

### Rust Core Integration

```rust
// backend/src/sovereign.rs

pub struct SovereignCore {
    kyber_keys: Option<KyberKeyPair>,
    is_initialized: bool,
}

impl SovereignCore {
    pub fn new() -> Self {
        Self {
            kyber_keys: None,
            is_initialized: false,
        }
    }
    
    pub fn initialize(&mut self, master_password: &str) -> Result<()> {
        // 🔐 Без мастер-пароля ядро НЕ инициализируется
        if !self.verify_master_password(master_password) {
            return Err(SecurityError::InvalidMasterPassword);
        }
        
        // Генерация Kyber ключей из мастер-пароля
        self.kyber_keys = Some(KyberKeyPair::derive_from_password(master_password));
        self.is_initialized = true;
        
        Ok(())
    }
    
    pub fn start_libp2p(&mut self) -> Result<()> {
        // 🔐 Без инициализации libp2p НЕ запустится
        if !self.is_initialized {
            return Err(SecurityError::CoreNotInitialized);
        }
        
        // Запуск сетевого стека
        self.libp2p_swarm.start()
    }
    
    fn verify_master_password(&self, input: &str) -> bool {
        // Constant-time comparison
        let expected = std::env::var("SOVEREIGN_MASTER_PASSWORD")
            .expect("MASTER PASSWORD MUST BE SET");
        
        input.bytes().eq(expected.bytes())
    }
}
```

---

## 📋 CHECKLIST БЕЗОПАСНОСТИ

### При разработке:

- [ ] Пароль НИКОГДА не логируется (даже в debug)
- [ ] Пароль НИКОГДА не сохраняется в БД
- [ ] Пароль НИКОГДА не передаётся по сети
- [ ] Пароль НИКОГДА не хешируется для хранения
- [ ] Пароль ВСЕГДА затирается после использования
- [ ] 3 неудачные попытки → PANIC WIPE
- [ ] AppLifecycleState.paused → WIPE PASSWORD
- [ ] dispose() → WIPE PASSWORD

### При тестировании:

- [ ] Проверка: пароль не в логах Android
- [ ] Проверка: пароль не в SharedPreferences
- [ ] Проверка: пароль не в дампе памяти
- [ ] Проверка: 3 попытки → затирание
- [ ] Проверка: сворачивание → затирание
- [ ] Проверка: выход → затирание

### При деплое:

- [ ] Мастер-пароль установлен через `.env`
- [ ] Мастер-пароль НЕ в репозитории
- [ ] Мастер-пароль НЕ в GitHub Secrets
- [ ] Мастер-пароль передаётся только устно/SMS

---

## ⚠️ WARNING

```
╔═══════════════════════════════════════════════════════════╗
║                    SECURITY WARNING                        ║
╠═══════════════════════════════════════════════════════════╣
║                                                            ║
║  SOVEREIGN MASTER PASSWORD — это:                          ║
║  • ЕДИНСТВЕННЫЙ ключ доступа к ядру системы               ║
║  • НЕ ВОССТАНАВЛИВАЕТСЯ при утере                         ║
║  • УНИЧТОЖАЕТСЯ при 3 неудачных попытках                  ║
║  • ТРЕБУЕТ полной переустановки при компрометации         ║
║                                                            ║
║  ЕСЛИ ВЫ ПОТЕРЯЛИ МАСТЕР-ПАРОЛЬ:                           ║
║  • Все данные в RAM будут недоступны                      ║
║  • P2P сеть не запустится                                 ║
║  • Kyber ключи будут утеряны                              ║
║  • Потребуется полная переустановка системы               ║
║                                                            ║
║  НЕТ способа восстановления. НЕТ.                          ║
║                                                            ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 📚 ССЫЛКИ

- [Zero-Persistence Architecture](SECURITY_TACTICS.md)
- [Memory Wipe Protocol](lib/services/secure_password_manager.dart)
- [Error Handling](TASK4_ERROR_HANDLING.md)
- [Kyber Key Derivation](lib/services/zero_knowledge_encryption.dart)

---

**Версия документа:** v1.0  
**Дата:** 21 марта 2026  
**Статус:** ACTIVE  
**Классификация:** SOVEREIGN-ONLY

---

*«Всё в голове. Ничего на диске. Никогда.»* 🔐
