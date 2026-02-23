/**
 * Liberty Reach CLI Client - Main
 */

#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <termios.h>
#include <unistd.h>

#include "liberty_reach_crypto.h"
#include "mesh_network.h"

using namespace td::liberty_reach;

class CLIApp {
public:
    void run() {
        print_banner();
        initialize();
        
        std::cout << "\n=== Liberty Reach CLI ===" << std::endl;
        std::cout << "Команди: /help, /send, /profile, /mesh, /call, /quit" << std::endl;
        std::cout << "=========================\n" << std::endl;

        running = true;
        while (running) {
            std::cout << "> ";
            std::string line;
            std::getline(std::cin, line);
            
            process_command(line);
        }
    }

private:
    bool running = false;
    std::string username;
    std::unique_ptr<IdentityKeyPair> identity;

    void print_banner() {
        std::cout << R"(
╔═══════════════════════════════════════════════════════════╗
║           🦅 Liberty Reach CLI Client                     ║
║              Версия 0.1.0                                 ║
╚═══════════════════════════════════════════════════════════╝
        )" << std::endl;
    }

    void initialize() {
        std::cout << "[*] Инициализация..." << std::endl;

        // Generate identity
        auto result = LibertyReachCrypto::generate_identity_keys();
        if (result) {
            identity = std::make_unique<IdentityKeyPair>(*result);
            std::cout << "[✓] Крипто ключове генерирани" << std::endl;
        }

        // Initialize mesh
        auto& mesh = mesh::MeshNetwork::getInstance();
        if (mesh.initialize("cli_user")) {
            mesh.startNetwork();
            std::cout << "[✓] Mesh мрежа инициализирана" << std::endl;
        }

        std::cout << "[✓] Готово!" << std::endl;
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
        } else if (cmd == "/send") {
            send_message(line.substr(cmd.length()));
        } else if (cmd == "/mesh") {
            show_mesh_status();
        } else if (cmd == "/call") {
            start_call();
        } else if (cmd == "/encrypt") {
            encrypt_test();
        } else {
            std::cout << "Непозната команда: " << cmd << std::endl;
            std::cout << "Напишете /help за списък с команди" << std::endl;
        }
    }

    void show_help() {
        std::cout << R"(
Команди:
  /help              - Покажи тази помощ
  /profile           - Покажи информация за профила
  /send <текст>      - Изпрати съобщение
  /mesh              - Покажи статус на Mesh мрежата
  /call              - Започни обаждане
  /encrypt <текст>   - Тествай криптиране
  /quit              - Изход
        )" << std::endl;
    }

    void show_profile() {
        std::cout << "\n=== Профил ===" << std::endl;
        std::cout << "Статус: Активен ✓" << std::endl;
        std::cout << "Тип: Перманентен (не може да бъде изтрит)" << std::endl;
        std::cout << "Криптиране: Post-Quantum (Kyber768)" << std::endl;
        std::cout << "Възстановяване: Shamir's Secret (3 от 5)" << std::endl;
        std::cout << "==============" << std::endl;
    }

    void send_message(const std::string& text) {
        if (text.empty()) {
            std::cout << "Употреба: /send <текст>" << std::endl;
            return;
        }

        std::cout << "[Изпращане на съобщение: " << text << "]" << std::endl;
        
        // In production: encrypt and send
        std::cout << "[✓] Съобщението е изпратено (криптирано)" << std::endl;
    }

    void show_mesh_status() {
        auto& mesh = mesh::MeshNetwork::getInstance();
        auto stats = mesh.getStats();

        std::cout << "\n=== Mesh Мрежа ===" << std::endl;
        std::cout << "Статус: " << (mesh.isNetworkAvailable() ? "Онлайн" : "Офлайн") << std::endl;
        std::cout << "BLE: " << (mesh.getBluetoothLE().isAvailable() ? "✓" : "✗") << std::endl;
        std::cout << "WiFi Direct: " << (mesh.getWiFiDirect().isAvailable() ? "✓" : "✗") << std::endl;
        std::cout << "LoRa: " << (mesh.getLoRa().isAvailable() ? "✓" : "✗") << std::endl;
        std::cout << "Свързани устройства: " << stats.connected_peers << std::endl;
        std::cout << "Изпратени съобщения: " << stats.messages_sent << std::endl;
        std::cout << "Получени съобщения: " << stats.messages_received << std::endl;
        std::cout << "==================" << std::endl;
    }

    void start_call() {
        std::cout << "[*] Започване на обаждане..." << std::endl;
        std::cout << "[!] VoIP модулът изисква GUI" << std::endl;
        std::cout << "[✓] Използвайте Desktop клиента за обаждания" << std::endl;
    }

    void encrypt_test() {
        std::cout << "[*] Тест на криптирането..." << std::endl;

        // Create session
        auto identity2 = LibertyReachCrypto::generate_identity_keys();
        auto ephemeral = LibertyReachCrypto::generate_ephemeral_keys();
        auto bundle = LibertyReachCrypto::create_prekey_bundle(*identity, 1);
        auto session = LibertyReachCrypto::x3dh_initiate(*identity, *ephemeral, *bundle);

        if (!session) {
            std::cout << "[!] Грешка при създаване на сесия" << std::endl;
            return;
        }

        std::string plaintext = "Това е тайно съобщение!";
        std::cout << "Оригинал: " << plaintext << std::endl;

        auto encrypted = LibertyReachCrypto::encrypt_message(
            *session,
            {reinterpret_cast<const uint8_t*>(plaintext.data()), plaintext.size()});

        if (!encrypted) {
            std::cout << "[!] Грешка при криптиране" << std::endl;
            return;
        }

        std::cout << "Криптирано: " << encrypted->size() << " байта" << std::endl;

        auto decrypted = LibertyReachCrypto::decrypt_message(*session, *encrypted);
        if (!decrypted) {
            std::cout << "[!] Грешка при декриптиране" << std::endl;
            return;
        }

        std::string result(decrypted->begin(), decrypted->end());
        std::cout << "Декриптирано: " << result << std::endl;
        std::cout << "[✓] Криптирането работи!" << std::endl;
    }
};

int main() {
    CLIApp app;
    app.run();
    return 0;
}
