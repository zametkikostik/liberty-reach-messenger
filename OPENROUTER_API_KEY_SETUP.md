# 🔑 OPENROUTER API KEY - ИНСТРУКЦИЯ

**Дата:** 22 марта 2026 г.  
**Статус:** ✅ Готово к использованию

---

## 📋 ЧТО ТАКОЕ OPENROUTER?

**OpenRouter** — единый API для доступа к множеству AI моделей:
- ✅ Qwen 2.5 72B Instruct
- ✅ GPT-4, GPT-3.5
- ✅ Claude 3 (Opus, Sonnet, Haiku)
- ✅ Llama 3
- ✅ Gemma
- ✅ И многие другие

**URL:** https://openrouter.ai

---

## 🚀 ПОЛУЧЕНИЕ API КЛЮЧА (БЕСПЛАТНО)

### Шаг 1: Регистрация

1. Откройте: **https://openrouter.ai**
2. Нажмите **"Sign In"** (вверху справа)
3. Войдите через:
   - Google аккаунт
   - GitHub аккаунт
   - Email

### Шаг 2: Создание ключа

1. Откройте: **https://openrouter.ai/keys**
2. Нажмите **"Create Key"**
3. Введите имя ключа (например: `Liberty Reach`)
4. **Скопируйте ключ** (начинается с `sk-or-v1-...`)

⚠️ **Ключ показывается только один раз!** Сохраните его.

### Шаг 3: Настройка .env.local

```bash
cd /path/to/liberty-sovereign

# Отредактируйте .env.local
nano .env.local

# Добавьте:
OPENROUTER_API_KEY=sk-or-v1-ваш_ключ_здесь
```

### Шаг 4: Пересборка APK

```bash
cd mobile

flutter build apk --release \
  --dart-define=OPENROUTER_API_KEY=sk-or-v1-ваш_ключ_здесь \
  --dart-define=ADMIN_MASTER_KEY=YourSecurePassword2026! \
  --dart-define=APP_MASTER_SALT=YourSaltValue123
```

---

## 💰 ТАРИФЫ

### Бесплатные модели (no credit card):

| Модель | Описание | Лимит |
|--------|----------|-------|
| `qwen/qwen-2.5-72b-instruct:free` | Qwen 2.5 72B | ~100 запросов/день |
| `meta-llama/llama-3-8b-instruct:free` | Llama 3 8B | ~100 запросов/день |
| `google/gemma-7b-it:free` | Gemma 7B | ~100 запросов/день |

### Платные модели (pay per token):

| Модель | Цена (за 1K токенов) |
|--------|---------------------|
| `openai/gpt-4-turbo` | $0.01 / $0.03 |
| `anthropic/claude-3-opus` | $0.015 / $0.075 |
| `qwen/qwen-2.5-72b-instruct` | $0.0007 / $0.0007 |

**Минимальный депозит:** $5 (хватит надолго!)

---

## 🎯 ИСПОЛЬЗОВАНИЕ В ПРИЛОЖЕНИИ

### 1. AI Assistant Screen

Откройте в приложении:
```
Настройки → AI Assistant
```

**Режимы:**
- 💬 **Чат** — обычный диалог с AI
- 🌍 **Перевод** — перевод на русский
- 📝 **Саммаризация** — краткое содержание
- 💻 **Генерация кода** — помощь программисту

### 2. Примеры запросов

**Чат:**
```
"Расскажи про квантовые компьютеры"
```

**Перевод:**
```
"Hello, how are you?" → "Привет, как дела?"
```

**Саммаризация:**
```
[Длинный текст] → [3 предложения]
```

**Генерация кода:**
```
"Напиши функцию для сортировки массива на Dart"
```

---

## 🔧 НАСТРОЙКИ

### Выбор модели

В `.env.local`:

```bash
# Бесплатная модель (рекомендуется)
OPENROUTER_MODEL=qwen/qwen-2.5-72b-instruct:free

# Платная модель (лучшее качество)
OPENROUTER_MODEL=qwen/qwen-2.5-72b-instruct

# GPT-4
OPENROUTER_MODEL=openai/gpt-4-turbo

# Claude 3
OPENROUTER_MODEL=anthropic/claude-3-opus
```

### Таймауты

```bash
# Время ожидания ответа (секунды)
AI_TIMEOUT_SECS=30

# Максимум попыток
AI_MAX_RETRIES=3
```

---

## 📊 МОНИТОРИНГ

### Проверка баланса

1. Откройте: https://openrouter.ai/credit
2. Посмотрите текущий баланс

### История запросов

1. Откройте: https://openrouter.ai/activity
2. Просмотрите все запросы

---

## 🆘 ПРОБЛЕМЫ

### "AI service not configured"

**Причина:** API ключ не установлен  
**Решение:** Добавьте `OPENROUTER_API_KEY` в .env.local и пересоберите APK

### "API Error 401"

**Причина:** Неверный ключ  
**Решение:** Проверьте ключ в .env.local

### "API Error 429"

**Причина:** Превышен лимит  
**Решение:** Подождите или используйте платную модель

### "API Error 500"

**Причина:** Ошибка сервера OpenRouter  
**Решение:** Попробуйте позже

---

## 📚 ССЫЛКИ

- **Главная:** https://openrouter.ai
- **Ключи:** https://openrouter.ai/keys
- **Модели:** https://openrouter.ai/models
- **Документация:** https://openrouter.ai/docs
- **Баланс:** https://openrouter.ai/credit
- **Активность:** https://openrouter.ai/activity

---

## ✅ ЧЕК-ЛИСТ

- [x] Зарегистрирован на OpenRouter
- [x] API ключ получен
- [x] Ключ добавлен в .env.local
- [x] APK пересобран с ключом
- [x] AI Assistant работает
- [x] Тестовый запрос успешен

---

**«AI теперь доступен в приложении!»** 🤖

*Liberty Reach AI Team*  
*22 марта 2026 г.*
