/**
 * Free Translation Module
 * Uses free APIs: LibreTranslate, MyMemory, Google Translate (unofficial)
 */

#include <string>
#include <vector>
#include <map>
#include <curl/curl.h>
#include <json/json.h>

namespace td {
namespace liberty_reach {
namespace translation {
namespace free {

// ============================================
// FREE TRANSLATION APIS
// ============================================

/**
 * Free translation API endpoints
 */
const std::vector<std::string> FREE_APIS = {
    "https://libretranslate.com/translate",
    "https://api.mymemory.translated.net/get",
    "https://translate.googleapis.com/translate_a/single"
};

/**
 * Language codes for free APIs
 */
std::map<std::string, std::string> LANG_CODES = {
    {"bg", "Bulgarian"},
    {"en", "English"},
    {"ru", "Russian"},
    {"de", "German"},
    {"fr", "French"},
    {"es", "Spanish"},
    {"it", "Italian"},
    {"pt", "Portuguese"},
    {"pl", "Polish"},
    {"uk", "Ukrainian"},
    {"tr", "Turkish"},
    {"zh", "Chinese"},
    {"ja", "Japanese"},
    {"ko", "Korean"},
    {"ar", "Arabic"}
};

// Callback for CURL
static size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* userp) {
    size_t realsize = size * nmemb;
    userp->append((char*)contents, realsize);
    return realsize;
}

/**
 * Translate using LibreTranslate (free, open-source)
 */
std::string translateLibreTranslate(
    const std::string& text,
    const std::string& source_lang,
    const std::string& target_lang) {
    
    CURL* curl = curl_easy_init();
    if (!curl) return "";
    
    std::string response;
    std::string url = "https://libretranslate.com/translate";
    
    // Prepare POST data
    std::string post_data = "q=" + curl_easy_escape(curl, text.c_str(), text.length()) +
                           "&source=" + source_lang +
                           "&target=" + target_lang +
                           "&format=text";
    
    struct curl_slist* headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
    
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)&response);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    
    CURLcode res = curl_easy_perform(curl);
    
    if (res == CURLE_OK) {
        // Parse JSON response
        // In production: use proper JSON parser
        size_t pos = response.find("\"translatedText\"");
        if (pos != std::string::npos) {
            size_t start = response.find(":", pos) + 2;
            size_t end = response.find("\"", start + 1);
            std::string translated = response.substr(start, end - start);
            curl_easy_cleanup(curl);
            curl_slist_free_all(headers);
            return translated;
        }
    }
    
    curl_easy_cleanup(curl);
    curl_slist_free_all(headers);
    return "";
}

/**
 * Translate using MyMemory API (free, 1000 chars/day)
 */
std::string translateMyMemory(
    const std::string& text,
    const std::string& source_lang,
    const std::string& target_lang) {
    
    CURL* curl = curl_easy_init();
    if (!curl) return "";
    
    std::string response;
    std::string url = "https://api.mymemory.translated.net/get?q=" + 
                     curl_easy_escape(curl, text.c_str(), text.length()) +
                     "&langpair=" + source_lang + "|" + target_lang;
    
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)&response);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    
    CURLcode res = curl_easy_perform(curl);
    
    if (res == CURLE_OK) {
        // Parse JSON response
        size_t pos = response.find("\"translation\"");
        if (pos != std::string::npos) {
            size_t start = response.find(":", pos) + 2;
            size_t end = response.find("\"", start + 1);
            std::string translated = response.substr(start, end - start);
            curl_easy_cleanup(curl);
            return translated;
        }
    }
    
    curl_easy_cleanup(curl);
    return "";
}

/**
 * Translate using Google Translate (unofficial, free)
 */
std::string translateGoogle(
    const std::string& text,
    const std::string& source_lang,
    const std::string& target_lang) {
    
    CURL* curl = curl_easy_init();
    if (!curl) return "";
    
    std::string response;
    std::string url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + 
                     source_lang + "&tl=" + target_lang + "&dt=t&q=" +
                     curl_easy_escape(curl, text.c_str(), text.length());
    
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)&response);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "Mozilla/5.0");
    
    CURLcode res = curl_easy_perform(curl);
    
    if (res == CURLE_OK) {
        // Parse JSON response (simplified)
        size_t pos = response.find("[[[\"");
        if (pos != std::string::npos) {
            size_t start = pos + 4;
            size_t end = response.find("\"", start);
            std::string translated = response.substr(start, end - start);
            curl_easy_cleanup(curl);
            return translated;
        }
    }
    
    curl_easy_cleanup(curl);
    return "";
}

/**
 * Main free translation function
 * Tries multiple free APIs until one works
 */
std::string translateFree(
    const std::string& text,
    const std::string& target_lang,
    const std::string& source_lang = "auto") {
    
    if (text.empty()) return "";
    
    // Try LibreTranslate first (completely free, no limits)
    std::string result = translateLibreTranslate(text, source_lang, target_lang);
    if (!result.empty()) return result;
    
    // Try MyMemory (free, 1000 chars/day)
    result = translateMyMemory(text, source_lang, target_lang);
    if (!result.empty()) return result;
    
    // Try Google Translate (unofficial)
    result = translateGoogle(text, source_lang, target_lang);
    if (!result.empty()) return result;
    
    // Fallback: return original text
    return text;
}

/**
 * Detect language (free)
 */
std::string detectLanguageFree(const std::string& text) {
    // Simple heuristic detection
    for (char c : text) {
        if (c >= 0x410 && c <= 0x44F) {
            // Cyrillic
            if (text.find("щ") != std::string::npos || 
                text.find("ъ") != std::string::npos) {
                return "bg";  // Bulgarian
            }
            if (text.find("і") != std::string::npos) {
                return "uk";  // Ukrainian
            }
            return "ru";  // Russian
        }
    }
    
    // Check for Latin characters
    if (text.find("the") != std::string::npos) return "en";
    if (text.find("der") != std::string::npos) return "de";
    if (text.find("le") != std::string::npos) return "fr";
    if (text.find("que") != std::string::npos) return "es";
    
    return "en";  // Default
}

/**
 * Batch translate (free)
 */
std::vector<std::string> batchTranslateFree(
    const std::vector<std::string>& texts,
    const std::string& target_lang) {
    
    std::vector<std::string> results;
    for (const auto& text : texts) {
        results.push_back(translateFree(text, target_lang));
    }
    return results;
}

/**
 * Translate with auto-detect
 */
std::string translateAutoFree(
    const std::string& text,
    const std::string& target_lang) {
    
    std::string detected = detectLanguageFree(text);
    if (detected == target_lang) {
        return text;  // Already in target language
    }
    return translateFree(text, target_lang, detected);
}

} // namespace free
} // namespace translation
} // namespace liberty_reach
} // namespace td
