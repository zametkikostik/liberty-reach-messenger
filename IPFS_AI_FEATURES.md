# 🌐 IPFS + 🤖 AI Aggregator - Liberty Reach v0.5.0

**Дата**: 23 Февраля 2026  
**Версия**: 0.5.0

---

## 🎯 ЧТО ДОБАВЛЕНО

### ✅ IPFS Облачное Хранилище:
- ✅ **Децентрализованное хранение** файлов
- ✅ **Мульти-провайдеры** (IPFS, Filecoin, Arweave)
- ✅ **Пиннинг сервисы** (Pinata, Infura, Web3.Storage)
- ✅ **Шифрование** файлов (AES-256)
- ✅ **Кэширование** локальное
- ✅ **Загрузка/выгрузка** файлов
- ✅ **Управление метаданными**
- ✅ **Поиск** по файлам
- ✅ **IPNS** (именованные записи)

### ✅ AI Агрегатор (OpenRouter):
- ✅ **10+ AI моделей** (GPT-4, Claude, Llama, Mistral, Gemini)
- ✅ **Чат completion** (синхронный + стриминг)
- ✅ **Генерация кода** и code review
- ✅ **Перевод текста** (AI-powered)
- ✅ **Саммари текста**
- ✅ **Vision** (анализ изображений)
- ✅ **OCR** (распознавание текста)
- ✅ **Embeddings** (векторные представления)
- ✅ **Генерация изображений** (Stable Diffusion)
- ✅ **Text-to-Speech** (озвучка)
- ✅ **Speech-to-Text** (транскрибация)

---

## 🌐 IPFS ХРАНИЛИЩЕ

### Поддерживаемые провайдеры:

```
🌐 IPFS - InterPlanetary File System (бесплатно)
💰 Filecoin - платное долгосрочное хранение
📦 Arweave - перманентное хранение (навсегда)
📌 Pinata - пиннинг сервис
☁️ Infura - пиннинг сервис
🌊 Web3.Storage - бесплатный пиннинг
```

### Использование:

```cpp
auto& ipfs = IPFSManager::getInstance();

// Инициализация
IPFSConfig config;
config.api_endpoint = "http://localhost:5001";
config.gateway_url = "https://ipfs.io/ipfs/";
ipfs.initialize(config);

// Загрузка файла
UploadResult result = ipfs.uploadFile(
    "/path/to/file.pdf",
    FileMetadata{
        .filename = "document.pdf",
        .content_type = "application/pdf",
        .owner_user_id = "user_123"
    }
);

std::cout << "CID: " << result.cid << std::endl;
std::cout << "Gateway: " << result.gateway_url << std::endl;
// QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco

// Скачивание файла
DownloadResult download = ipfs.downloadFile(result.cid, "/downloads/file.pdf");

// Загрузка с шифрованием
std::string encryption_key = ipfs.generateEncryptionKey();
UploadResult encrypted = ipfs.uploadEncryptedFile(
    "/path/to/secret.pdf",
    encryption_key
);

// Скачивание и расшифровка
DownloadResult decrypted = ipfs.downloadDecryptedFile(
    encrypted.cid,
    encryption_key
);

// Пиннинг на Pinata
PinningService pinata;
pinata.name = "Pinata";
pinata.api_key = "your_pinata_key";
ipfs.addPinningService(pinata);
ipfs.pinFile(result.cid, "Pinata");

// Статистика
StorageStats stats = ipfs.getStatistics();
std::cout << "Total files: " << stats.total_files << std::endl;
std::cout << "Total size: " << stats.total_size_bytes << " bytes" << std::endl;
```

### Filecoin интеграция:

```cpp
// Долгосрочное хранение на Filecoin
UploadResult deal = ipfs.storeOnFilecoin(
    result.cid,
    365,  // дней хранения
    "f1...wallet_address"
);

// Проверка статуса deals
auto status = ipfs.getDealStatus(deal.cid);
```

### Arweave интеграция:

```cpp
// Перманентное хранение (навсегда)
UploadResult arweave = ipfs.storeOnArweave(
    "/path/to/important.pdf",
    "arweave_wallet_key"
);

// Arweave транзакция
auto tx = ipfs.getArweaveTransaction(arweave.cid);
```

---

## 🤖 AI АГРЕГАТОР (OPENROUTER)

### Поддерживаемые модели:

```
🟢 OpenAI:
   - GPT-4 (8K context) - $0.03/1K input, $0.06/1K output
   - GPT-3.5-Turbo (4K) - $0.001/1K input, $0.002/1K output
   - GPT-4-Vision - мультимодальный

🟠 Anthropic:
   - Claude 3 (100K context) - $0.003/1K input, $0.015/1K output
   - Claude 2.1

🔵 Google:
   - Gemini Pro (32K) - $0.0005/1K input, $0.0015/1K output
   - Gemini Pro Vision

🟣 Meta:
   - Llama 2 70B - $0.0007/1K input, $0.0007/1K output
   - Llama 2 13B

🟡 Mistral:
   - Mistral Large (32K) - $0.002/1K input, $0.006/1K output
   - Mistral Medium
```

### Инициализация:

```cpp
auto& ai = AIAggregator::getInstance();

// Инициализация с OpenRouter API ключом
ai.initialize("your_openrouter_api_key");

// Или добавить ключи для каждого провайдера
ai.addAPIKey(AIProvider::OPENAI, "sk-openai-key");
ai.addAPIKey(AIProvider::ANTHROPIC, "sk-anthropic-key");
ai.addAPIKey(AIProvider::GOOGLE, "google-api-key");
```

### Чат:

```cpp
// Простой чат
std::string response = ai.simpleChat(
    "Привет! Как дела?",
    "Ты полезный ассистент.",  // системный промпт
    "openai/gpt-4"
);

// Чат с контекстом
std::vector<ChatMessage> messages = {
    {MessageRole::SYSTEM, "Ты русскоязычный ассистент.", "", "", {}, ""},
    {MessageRole::USER, "Расскажи о себе", "", "", {}, ""},
    {MessageRole::ASSISTANT, "Я AI ассистент...", "", "", {}, ""},
    {MessageRole::USER, "Что ты умеешь?", "", "", {}, ""}
};

std::string reply = ai.chatWithContext(messages, "anthropic/claude-3");
```

### Стриминг:

```cpp
ChatCompletionRequest request;
request.model = "openai/gpt-3.5-turbo";
request.messages = {
    {MessageRole::USER, "Расскажи длинную историю"}
};
request.stream = true;

ai.chatStream(request, [](const StreamChunk& chunk) {
    if (chunk.is_finished) {
        std::cout << "\n[Stream finished]" << std::endl;
    } else {
        std::cout << chunk.content << std::flush;
    }
});
```

### Генерация кода:

```cpp
std::string code = ai.generateCode(
    "Напиши функцию для сортировки массива",
    "python",
    "openai/gpt-4"
);

// Code review
std::string review = ai.reviewCode(
    "def sort(arr):\n    return arr.sort()",
    "python"
);
```

### Перевод текста:

```cpp
std::string translated = ai.translateText(
    "Hello, how are you?",
    "bulgarian",  // целевой язык
    "english"     // исходный (или "auto")
);
// "Здравей, как си?"
```

### Саммари текста:

```cpp
std::string summary = ai.summarizeText(
    long_text,
    200  // максимум слов
);
```

### Vision (анализ изображений):

```cpp
// Анализ изображения
std::string analysis = ai.analyzeImage(
    "https://example.com/image.jpg",
    "Что на этом изображении?"
);

// OCR (распознавание текста)
std::string text = ai.extractTextFromImage(
    "https://example.com/document.jpg"
);
```

### Embeddings:

```cpp
// Генерация embeddings
EmbeddingResult embedding = ai.generateEmbedding(
    "Текст для векторизации",
    "openai/text-embedding-ada-002"
);

std::vector<float> vector = embedding.embedding;  // 1536 dimensions

// Пакетная генерация
auto embeddings = ai.generateBatchEmbeddings(
    {"text1", "text2", "text3"}
);
```

### Генерация изображений:

```cpp
// Простая генерация
std::string image_url = ai.generateImageSimple(
    "Кот в космосе",
    "photorealistic"
);

// Расширенная генерация
ImageGenerationRequest request;
request.prompt = "Красивый закат над горами";
request.negative_prompt = "размыто, плохо качество";
request.width = 1024;
request.height = 1024;
request.steps = 50;
request.guidance_scale = 7.5;

ImageGenerationResult result = ai.generateImage(request);
```

### Text-to-Speech:

```cpp
// Озвучка текста
TTSRequest request;
request.text = "Привет! Это тест озвучки.";
request.voice = "alloy";  // или "echo", "fable", "onyx", "nova", "shimmer"
request.format = "mp3";

TTSResult tts = ai.generateSpeech(request);
std::cout << "Audio URL: " << tts.audio_url << std::endl;
```

### Speech-to-Text:

```cpp
// Транскрибация аудио
STTRequest request;
request.audio_url = "https://example.com/audio.mp3";
request.language = "ru";  // или "auto" для автоопределения

STTResult stt = ai.transcribeAudio(request);
std::cout << "Transcription: " << stt.text << std::endl;
std::cout << "Confidence: " << stt.confidence << std::endl;
```

---

## 💰 СТОИМОСТЬ (OpenRouter)

### Модели и цены:

| Модель | Input (1K tokens) | Output (1K tokens) | Context |
|--------|------------------|-------------------|---------|
| GPT-4 | $0.03 | $0.06 | 8K |
| GPT-3.5-Turbo | $0.001 | $0.002 | 4K |
| Claude 3 | $0.003 | $0.015 | 100K |
| Gemini Pro | $0.0005 | $0.0015 | 32K |
| Llama 2 70B | $0.0007 | $0.0007 | 4K |
| Mistral Large | $0.002 | $0.006 | 32K |

### Пример расчёта:

```
Запрос: 1000 tokens (input) + 500 tokens (output)
Модель: GPT-3.5-Turbo

Стоимость:
- Input: 1000 * $0.001/1000 = $0.001
- Output: 500 * $0.002/1000 = $0.001
Итого: $0.002 за запрос
```

---

## 🔒 БЕЗОПАСНОСТЬ

### IPFS:

```
✅ Шифрование AES-256 перед загрузкой
✅ Ключи не покидают устройство
✅ Мульти-провайдер резервирование
✅ Локальное кэширование
✅ Приватные пины (Pinata private pins)
```

### AI:

```
✅ API ключи хранятся локально
✅ HTTPS для всех запросов
✅ Rate limiting
✅ Кэширование ответов
✅ No logging по умолчанию
```

---

## 📊 СТАТИСТИКА

### Отслеживание использования:

```cpp
// IPFS статистика
StorageStats ipfs_stats = ipfs.getStatistics();
std::cout << "Files: " << ipfs_stats.total_files << std::endl;
std::cout << "Size: " << ipfs_stats.total_size_bytes << std::endl;
std::cout << "Uploaded: " << ipfs_stats.uploaded_bytes << std::endl;
std::cout << "Downloaded: " << ipfs_stats.downloaded_bytes << std::endl;

// AI статистика
AIAggregator::UsageStats ai_stats = ai.getUsageStats();
std::cout << "Requests: " << ai_stats.total_requests << std::endl;
std::cout << "Tokens: " << ai_stats.total_tokens_used << std::endl;
std::cout << "Cost: $" << ai_stats.total_cost_usd << std::endl;
```

---

## ✅ ИНТЕГРАЦИЯ В МЕССЕНДЖЕР

### Автоперевод сообщений:

```cpp
// При получении сообщения на другом языке
auto& translation = TranslationManager::getInstance();
auto& ai = AIAggregator::getInstance();

TextTranslation result = translation.translateText(
    received_message,
    Language::BULGARIAN  // целевой язык пользователя
);

// Или использовать AI для более качественного перевода
std::string ai_translated = ai.translateText(
    received_message,
    "bulgarian"
);
```

### AI Ассистент в чате:

```cpp
// Умные ответы
auto& ai_features = AdditionalFeaturesManager::getInstance().getAIAssistant();

auto smart_replies = ai_features.generateSmartReplies(
    "Как дела?"
);
// ["Отлично, спасибо!", "Нормально", "Супер!"]

// Саммари чата
std::string summary = ai_features.summarizeChat(messages);

// Извлечение задач
auto tasks = ai_features.extractTasks(conversation);
```

### Хранение файлов в IPFS:

```cpp
// При отправке файла
auto& ipfs = IPFSManager::getInstance();

UploadResult result = ipfs.uploadFile(
    file_path,
    FileMetadata{
        .filename = filename,
        .owner_user_id = user_id,
        .is_encrypted = true
    }
);

// Отправить CID получателю
send_message(to_user, "File: " + result.cid);
```

---

**ВСЁ РАБОТАЕТ! IPFS + AI в Liberty Reach! 🚀**
