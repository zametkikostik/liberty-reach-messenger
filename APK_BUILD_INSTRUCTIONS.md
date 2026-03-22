# 📦 APK BUILD INSTRUCTIONS

**Версия:** v0.16.1-cloud  
**Статус:** ✅ GitHub Actions настроен

---

## 🚀 БЫСТРАЯ СБОРКА (рекомендуется)

### Вариант 1: GitHub Actions (автоматически)

**Локальная сборка не требуется!**

1. **Создайте релиз на GitHub:**
   - https://github.com/zametkikostik/liberty-reach-messenger/releases
   - **Draft a new release**
   - Tag: `v0.16.1-cloud`
   - **Publish release**

2. **Workflow запустится автоматически:**
   - https://github.com/zametkikostik/liberty-reach-messenger/actions
   - Найдите **"Build & Release APK"**
   - Подождите 10-15 минут

3. **Скачайте APK:**
   - В **Artifacts** (кликните на workflow)
   - Или в **Releases** (автоматически добавится)

---

### Вариант 2: Ручной запуск workflow

1. Откройте: https://github.com/zametkikostik/liberty-reach-messenger/actions/workflows/build-release-apk.yml
2. **Run workflow**
3. Выберите ветку `main`
4. **Run workflow**
5. Подождите завершения
6. Скачайте из **Artifacts**

---

## 🔐 НАСТРОЙКА СЕКРЕТОВ

### GitHub Secrets (обязательно)

1. **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**

| Name | Value |
|------|-------|
| `ADMIN_MASTER_KEY` | Ваш секретный ключ |
| `APP_MASTER_SALT` | Соль для P2P |

### Пример:

```
Name: ADMIN_MASTER_KEY
Value: YourSecurePassword2026!

Name: APP_MASTER_SALT
Value: YourRandomSaltValue123
```

---

## 📊 ЧТО ПРОИСХОДИТ

```yaml
1. Checkout code           → Загрузка кода
2. Setup Java 17           → Установка Java
3. Setup Flutter 3.24.0    → Установка Flutter
4. Flutter pub get         → Зависимости
5. Build APK               → Сборка с секретами
6. Upload Artifact         → Загрузка APK (30 дней)
7. Add to Release          → Авто-добавление в релиз
```

---

## 📥 СКАЧИВАНИЕ APK

### Из Artifacts:

1. Откройте workflow
2. Внизу **Artifacts**
3. Нажмите `liberty-reach-apk-XXX`
4. APK скачается (zip)
5. Распакуйте: `app-release.apk`

### Из Releases:

1. https://github.com/zametkikostik/liberty-reach-messenger/releases
2. Выберите тег `v0.16.1-cloud`
3. Скачайте `app-release.apk`

---

## 🛠️ ЛОКАЛЬНАЯ СБОРКА (не рекомендуется)

Если всё же хотите собрать локально:

```bash
cd mobile

# 1. Очистка
flutter clean

# 2. Зависимости
flutter pub get

# 3. Сборка
flutter build apk --release \
  --dart-define=ADMIN_MASTER_KEY=YourKey \
  --dart-define=APP_MASTER_SALT=YourSalt

# 4. APK будет в:
build/app/outputs/flutter-apk/app-release.apk
```

⚠️ **Требует:**
- Android SDK
- Java 17
- Настроенный keystore (для подписи)

---

## 📋 ЧЕК-ЛИСТ

- [ ] Секреты добавлены в GitHub
- [ ] Тег релиза создан
- [ ] Workflow запущен
- [ ] APK скачан
- [ ] APK установлен на устройство

---

## 🆘 ПРОБЛЕМЫ

### Workflow failed

**Решение:**
- Откройте workflow, посмотрите логи
- Проверьте что секреты добавлены
- Попробуйте запустить снова

### Artifact expired

**Решение:**
- Артефакты хранятся 30 дней
- Запустите workflow снова
- Или скачайте из Releases

### APK not installing

**Решение:**
- Разрешите установку из неизвестных источников
- Проверьте что APK не повреждён
- Попробуйте собрать снова

---

## 📚 ДОКУМЕНТАЦИЯ

- [GITHUB_ACTIONS_BUILD.md](GITHUB_ACTIONS_BUILD.md) — полное руководство
- [build-release-apk.yml](.github/workflows/build-release-apk.yml) — workflow файл

---

## ✅ ССЫЛКИ

- **Репозиторий:** https://github.com/zametkikostik/liberty-reach-messenger
- **Releases:** https://github.com/zametkikostik/liberty-reach-messenger/releases
- **Actions:** https://github.com/zametkikostik/liberty-reach-messenger/actions

---

**«GitHub Actions соберёт всё за вас!»** 🚀

*Liberty Reach Build Team*  
*22 марта 2026 г.*
