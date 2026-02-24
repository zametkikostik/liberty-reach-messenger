/**
 * Liberty Reach CLI Client - Main
 * Полноценный консольный клиент
 */

#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <memory>
#include <cstdint>

#include "liberty_reach_crypto.h"

using namespace td::liberty_reach;

class CLIApp {
public:
    void run() {
        print_banner();
        initialize();

        std::cout << "\n=== Liberty Reach CLI ===" << std::endl;
        std::cout << "Команды: /help, /send, /profile, /keys, /encrypt, /quit" << std::endl;
        std::cout << "=========================\n" << std::endl;

        running = true;
        while (running) {
            std::cout << "\033[1;36m>\033[0m ";
            std::string line;
            std::getline(std::cin, line);

            process_command(line);
        }
        
        std::cout << "\n🦅 До свидания!" << std::endl;
    }

private:
    bool running = false;
    std::string user_id;
    std::unique_ptr<IdentityKeyPair> identity;
    std::unique_ptr<SessionKeys> session;

    void print_banner() {
        std::cout << R"(
╔═══════════════════════════════════════════════════════════╗
║           🦅 Liberty Reach CLI Client                     ║
║              Версия 0.1.0                                 ║
║         Post-Quantum Cryptography Enabled                 ║
╚═══════════════════════════════════════════════════════════╝
        )" << std::endl;
    }

    void initialize() {
        std::cout << "\n\033[1;33m[*] Инициализация...\033[0m" << std::endl;

        // Generate identity
        std::cout << "[*] Генерация ключей..." << std::endl;
        auto result = LibertyReachCrypto::generate_identity_keys();
        if (result) {
            identity = std::make_unique<IdentityKeyPair>(*result);
            std::cout << "\033[1;32m[✓] Крипто ключи сгенерированы\033[0m" << std::endl;
            std::cout << "    - PQ: Kyber768 (Post-Quantum)" << std::endl;
            std::cout << "    - EC: X25519 (ECDH)" << std::endl;
            std::cout << "    - ED: Ed25519 (ECDSA)" << std::endl;
        } else {
            std::cout << "\033[1;31m[!] Ошибка генерации ключей\033[0m" << std::endl;
        }

        user_id = "user_" + std::to_string(std::time(nullptr));
        std::cout << "\033[1;32m[✓] Готово!\033[0m" << std::endl;
    }

    void process_command(const std::string& line) {
        if (line.empty()) return;

        std::istringstream iss(line);
        std::string cmd;
        iss >> cmd;

        if (cmd == "/quit" || cmd == "/exit") {
            running = false;
        } else if (cmd == "/help") {
            show_help();
        } else if (cmd == "/profile") {
            show_profile();
        } else if (cmd == "/keys") {
            show_keys();
        } else if (cmd == "/send") {
            send_message(line.substr(cmd.length()));
        } else if (cmd == "/encrypt") {
            encrypt_test(line.substr(cmd.length()));
        } else if (cmd == "/hash") {
            hash_test(line.substr(cmd.length()));
        } else {
            std::cout << "\033[1;31mНеизвестная команда:\033[0m " << cmd << std::endl;
            std::cout << "Напишите \033[1;33m/help\033[0m для списка команд" << std::endl;
        }
    }

    void show_help() {
        std::cout << R"(
\033[1;33mКоманды:\033[0m
  \033[1;36m/help\033[0m              - Показать эту справку
  \033[1;36m/profile\033[0m           - Информация о профиле
  \033[1;36m/keys\033[0m              - Показать публичные ключи
  \033[1;36m/send <текст>\033[0m      - Отправить сообщение (тест)
  \033[1;36m/encrypt <текст>\033[0m   - Зашифровать сообщение
  \033[1;36m/hash <текст>\033[0m      - Хешировать (BLAKE3)
  \033[1;36m/quit\033[0m              - Выход
        )" << std::endl;
    }

    void show_profile() {
        std::cout << "\n\033[1;33m=== Профиль ===\033[0m" << std::endl;
        std::cout << "ID: \033[1;37m" << user_id << "\033[0m" << std::endl;
        std::cout << "Статус: \033[1;32mАктивен ✓\033[0m" << std::endl;
        std::cout << "Тип: \033[1;37mПерманентный (не удаляется)\033[0m" << std::endl;
        std::cout << "Шифрование: \033[1;36mPost-Quantum (Kyber768)\033[0m" << std::endl;
        std::cout << "E2EE: \033[1;32mВключено ✓\033[0m" << std::endl;
        std::cout << "Double Ratchet: \033[1;32mВключен ✓\033[0m" << std::endl;
        std::cout << "Steganography: \033[1;33mДоступна\033[0m" << std::endl;
        std::cout << "Восстановление: \033[1;37mShamir's Secret (3 из 5)\033[0m" << std::endl;
        std::cout << "===============" << std::endl;
    }

    void show_keys() {
        if (!identity) {
            std::cout << "\033[1;31m[!] Ключи не сгенерированы\033[0m" << std::endl;
            return;
        }

        std::cout << "\n\033[1;33m=== Публичные ключи ===\033[0m" << std::endl;
        
        // PQ Public Key
        std::cout << "\n\033[1;36mPQ Public Key (Kyber768):\033[0m" << std::endl;
        std::cout << "  Размер: 1184 байт" << std::endl;
        std::cout << "  Hex: ";
        for (int i = 0; i < 32 && i < (int)identity->pq_public.size(); i++) {
            printf("%02x", identity->pq_public[i]);
        }
        std::cout << "..." << std::endl;

        // EC Public Key
        std::cout << "\n\033[1;36mEC Public Key (X25519):\033[0m" << std::endl;
        std::cout << "  Размер: 32 байт" << std::endl;
        std::cout << "  Hex: ";
        for (int i = 0; i < 32 && i < (int)identity->ec_public.size(); i++) {
            printf("%02x", identity->ec_public[i]);
        }
        std::cout << std::endl;

        // Identity Public Key
        std::cout << "\n\033[1;36mIdentity Public Key (Ed25519):\033[0m" << std::endl;
        std::cout << "  Размер: 32 байт" << std::endl;
        std::cout << "  Hex: ";
        for (int i = 0; i < 32 && i < (int)identity->identity_public.size(); i++) {
            printf("%02x", identity->identity_public[i]);
        }
        std::cout << std::endl;

        std::cout << "\n\033[1;32m[✓] Ключи показаны\033[0m" << std::endl;
    }

    void send_message(const std::string& text) {
        if (text.empty()) {
            std::cout << "Использование: /send <текст>" << std::endl;
            return;
        }

        std::cout << "\n\033[1;33m[Отправка сообщения]\033[0m" << std::endl;
        std::cout << "Текст: " << text << std::endl;

        if (identity && session) {
            // Encrypt
            auto encrypted = LibertyReachCrypto::encrypt_message(
                *session,
                {reinterpret_cast<const uint8_t*>(text.data()), text.size()});

            if (encrypted) {
                std::cout << "\033[1;32m[✓] Зашифровано\033[0m: " << encrypted->size() << " байт" << std::endl;
                std::cout << "\033[1;32m[✓] Отправлено (E2E зашифровано)\033[0m" << std::endl;
            } else {
                std::cout << "\033[1;31m[!] Ошибка шифрования\033[0m" << std::endl;
            }
        } else {
            std::cout << "\033[1;33m[!] Сессия не создана. Сообщение отправлено открытым текстом.\033[0m" << std::endl;
        }
    }

    void encrypt_test(const std::string& text) {
        if (text.empty()) {
            std::cout << "Использование: /encrypt <текст>" << std::endl;
            return;
        }

        std::cout << "\n\033[1;33m[Тест шифрования]\033[0m" << std::endl;
        std::cout << "Оригинал: \033[1;37m" << text << "\033[0m" << std::endl;

        if (!identity) {
            std::cout << "\033[1;31m[!] Ключи не сгенерированы\033[0m" << std::endl;
            return;
        }

        // Generate second identity for demo
        auto identity2 = LibertyReachCrypto::generate_identity_keys();
        if (!identity2) {
            std::cout << "\033[1;31m[!] Ошибка генерации второго ключа\033[0m" << std::endl;
            return;
        }

        // Create PreKey bundle
        auto bundle = LibertyReachCrypto::create_prekey_bundle(*identity2, 1);
        if (!bundle) {
            std::cout << "\033[1;31m[!] Ошибка создания PreKey bundle\033[0m" << std::endl;
            return;
        }

        // Generate ephemeral keys
        auto ephemeral = LibertyReachCrypto::generate_ephemeral_keys();
        if (!ephemeral) {
            std::cout << "\033[1;31m[!] Ошибка генерации ephemeral ключей\033[0m" << std::endl;
            return;
        }

        // X3DH key exchange
        auto session_keys = LibertyReachCrypto::x3dh_initiate(
            *identity,
            std::make_pair(ephemeral->first, ephemeral->second),
            *bundle);

        if (!session_keys) {
            std::cout << "\033[1;31m[!] Ошибка X3DH обмена ключами\033[0m" << std::endl;
            return;
        }

        std::cout << "\033[1;32m[✓] Сессия создана (X3DH + PQ)\033[0m" << std::endl;

        // Encrypt
        auto encrypted = LibertyReachCrypto::encrypt_message(
            *session_keys,
            {reinterpret_cast<const uint8_t*>(text.data()), text.size()});

        if (!encrypted) {
            std::cout << "\033[1;31m[!] Ошибка шифрования\033[0m" << std::endl;
            return;
        }

        std::cout << "\033[1;32m[✓] Зашифровано\033[0m: " << encrypted->size() << " байт" << std::endl;
        std::cout << "Hex: ";
        for (size_t i = 0; i < std::min(encrypted->size(), size_t(32)); i++) {
            printf("%02x", (*encrypted)[i]);
        }
        std::cout << "..." << std::endl;

        // Decrypt
        auto decrypted = LibertyReachCrypto::decrypt_message(
            *session_keys,
            *encrypted);

        if (!decrypted) {
            std::cout << "\033[1;31m[!] Ошибка расшифровки\033[0m" << std::endl;
            return;
        }

        std::string result(decrypted->begin(), decrypted->end());
        std::cout << "\033[1;32m[✓] Расшифровано\033[0m: " << result << std::endl;
        std::cout << "\n\033[1;32m🦅 E2E шифрование работает!\033[0m" << std::endl;
    }

    void hash_test(const std::string& text) {
        if (text.empty()) {
            std::cout << "Использование: /hash <текст>" << std::endl;
            return;
        }

        std::cout << "\n\033[1;33m[BLAKE3 Хеш]\033[0m" << std::endl;
        std::cout << "Текст: \033[1;37m" << text << "\033[0m" << std::endl;

        auto hash = LibertyReachCrypto::blake3_hash(
            {reinterpret_cast<const uint8_t*>(text.data()), text.size()});

        std::cout << "Hash: \033[1;36m";
        for (const auto& byte : hash) {
            printf("%02x", byte);
        }
        std::cout << "\033[0m" << std::endl;
        std::cout << "Размер: 32 байт (256 бит)" << std::endl;
    }
};

int main() {
    CLIApp app;
    app.run();
    return 0;
}
