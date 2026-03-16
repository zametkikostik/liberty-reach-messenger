# GitHub Secrets для "A Love Story"

## 🔐 Необходимые секреты

Добавь эти секреты в **Settings → Secrets and variables → Actions**:

### Для Android APK (обязательно)

| Secret Name | Описание | Пример |
|-------------|----------|--------|
| `KEYSTORE_BASE64` | Keystore файл в base64 | `UEsDBBQAAAAI...` |
| `KEYSTORE_PASSWORD` | Пароль от keystore | `mypassword123` |
| `KEY_PASSWORD` | Пароль от ключа | `keypassword456` |

### Для Cloudflare Worker (обязательно)

| Secret Name | Описание | Где получить |
|-------------|----------|--------------|
| `CLOUDFLARE_API_TOKEN` | API токен Cloudflare | [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) |

### Для Docker Hub (опционально)

| Secret Name | Описание | Пример |
|-------------|----------|--------|
| `DOCKER_USERNAME` | Логин Docker Hub | `zametkikostik` |
| `DOCKER_PASSWORD` | Пароль/токен Docker Hub | `dckr_pat_xxx` |

## 📋 Переменные (Variables)

Добавь в **Settings → Variables → Actions**:

| Variable Name | Описание | Пример |
|---------------|----------|--------|
| `CLOUDFLARE_ACCOUNT_SUBDOMAIN` | Subdomain Cloudflare Workers | `your-account` |

## 🚀 Как создать секреты

### 1. Cloudflare API Token

1. Открой https://dash.cloudflare.com/profile/api-tokens
2. Нажми **"Create Token"**
3. Выбери шаблон **"Edit Cloudflare Workers"**
4. Скопируй токен
5. Добавь в GitHub Secrets как `CLOUDFLARE_API_TOKEN`

### 2. Android Keystore Base64

```bash
# В терминале
base64 android/app/upload-keystore.jks > keystore.base64
# Скопируй содержимое keystore.base64 в GitHub Secrets
```

## ✅ Проверка

После добавления секретов:

1. Запуш изменения в `main`
2. Открой **Actions → Hybrid CI/CD Build**
3. Проверь, что оба job прошли успешно

## 📁 Структура workflow

```
.github/workflows/
├── hybrid_build.yml      # Основной workflow
├── build.yml            # Старый workflow (можно удалить)
└── SECRETS.md          # Этот файл
```
