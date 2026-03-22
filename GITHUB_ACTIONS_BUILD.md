# 📦 GITHUB ACTIONS - АВТОМАТИЧЕСКАЯ СБОРКА APK

**Проблема:** Локальная сборка требует настройки Android SDK, Keystore и т.д.  
**Решение:** GitHub Actions соберёт APK автоматически!

---

## 🚀 БЫСТРАЯ СБОРКА ЧЕРЕЗ GITHUB

### 1. Создайте релиз на GitHub

1. Откройте: https://github.com/zametkikostik/liberty-reach-messenger/releases
2. **Draft a new release**
3. Tag version: `v0.16.1-cloud`
4. Release title: `Liberty Reach v0.16.1-cloud`
5. **Publish release**

### 2. Запустите workflow

1. Откройте: https://github.com/zametkikostik/liberty-reach-messenger/actions
2. Выберите **"Build & Release APK"**
3. **Run workflow**
4. Выберите тег `v0.16.1-cloud`
5. **Run workflow**

### 3. Скачайте APK

Через 10-15 минут:
- APK появится в **Artifacts**
- Или в **Releases** (если настроено авто-добавление)

---

## 📋 WORKFLOW ФАЙЛ

Создайте `.github/workflows/build-release.yml`:

```yaml
name: Build & Release APK

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g., v0.16.1-cloud)'
        required: true
        default: 'v0.16.1-cloud'

env:
  FLUTTER_VERSION: '3.24.0'
  JAVA_VERSION: '17'

jobs:
  build:
    name: Build APK
    runs-on: ubuntu-latest
    
    defaults:
      run:
        working-directory: mobile
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true
      
      - name: Flutter pub get
        run: flutter pub get
      
      - name: Build Release APK
        run: |
          flutter build apk --release \
            --dart-define=ADMIN_MASTER_KEY=${{ secrets.ADMIN_MASTER_KEY }} \
            --dart-define=APP_MASTER_SALT=${{ secrets.APP_MASTER_SALT }}
      
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: liberty-reach-apk
          path: mobile/build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30
      
      - name: Add APK to Release
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v1
        with:
          files: mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔐 GITHUB SECRETS

Добавьте секреты в репозитории:

1. **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**

### Обязательные секреты:

| Name | Value |
|------|-------|
| `ADMIN_MASTER_KEY` | Ваш секретный ключ |
| `APP_MASTER_SALT` | Соль для P2P |

### Опционально (для подписи APK):

| Name | Value |
|------|-------|
| `KEYSTORE_BASE64` | BASE64 keystore |
| `KEYSTORE_PASSWORD` | Пароль keystore |
| `KEY_ALIAS` | Алиас ключа |
| `KEY_PASSWORD` | Пароль ключа |

---

## 📊 СТАТУС СБОРКИ

### Проверка статуса

1. Откройте: https://github.com/zametkikostik/liberty-reach-messenger/actions
2. Найдите последний запуск
3. Статус:
   - 🟢 **Success** — APK готов
   - 🔴 **Failed** — нажмите на workflow, посмотрите логи

### Скачивание APK

1. Нажмите на успешный workflow
2. Внизу страницы **Artifacts**
3. Нажмите `liberty-reach-apk`
4. APK скачается (zip архив)

---

## 🛠️ ЛОКАЛЬНАЯ СБОРКА (альтернатива)

Если хотите собрать локально:

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
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 📋 ЧЕК-ЛИСТ

- [ ] Создан тег на GitHub
- [ ] Workflow файл добавлен
- [ ] Секреты настроены
- [ ] Workflow запущен
- [ ] APK скачан
- [ ] APK загружен в Release

---

## 🆘 ПРОБЛЕМЫ

### Ошибка: "Gradle build failed"

**Решение:**
- Проверьте логи workflow
- Убедитесь что Flutter версия совпадает
- Попробуйте `flutter clean`

### Ошибка: "Secrets not found"

**Решение:**
- Проверьте что секреты добавлены в Settings → Secrets
- Имена секретов чувствительны к регистру

### Ошибка: "Artifact expired"

**Решение:**
- Артефакты хранятся 30 дней
- Запустите workflow снова
- Или скачайте из Releases

---

## 📚 ДОКУМЕНТАЦИЯ

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter GitHub Actions](https://github.com/marketplace/actions/flutter-action)
- [Upload to Release](https://github.com/marketplace/actions/action-gh-release)

---

**«Автоматизация — ключ к успеху!»** 🚀

*Liberty Reach Build Team*
