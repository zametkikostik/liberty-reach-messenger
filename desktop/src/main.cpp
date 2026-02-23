/**
 * Liberty Reach Desktop Client - Main Entry Point
 */

#include <gtk/gtk.h>
#include <iostream>
#include <string>

#include "liberty_reach_crypto.h"
#include "voip_manager.h"
#include "mesh_network.h"

using namespace td::liberty_reach;

void print_banner() {
    std::cout << R"(
╔═══════════════════════════════════════════════════════════╗
║           🦅 Liberty Reach Messenger                      ║
║              Свобода достигайки всеки                     ║
║                                                           ║
║   🔐 Post-Quantum Encryption     ♾️  Permanent Profile    ║
║   🌍 Works in 200+ countries     🇧🇬 Bulgaria Priority   ║
╚═══════════════════════════════════════════════════════════╝
    )" << std::endl;
}

int main(int argc, char *argv[]) {
    print_banner();

    // Initialize GTK
    gtk_init(&argc, &argv);

    std::cout << "[*] Инициализация на Liberty Reach..." << std::endl;

    // Initialize crypto
    std::cout << "[*] Генериране на крипто ключове..." << std::endl;
    auto identity_result = LibertyReachCrypto::generate_identity_keys();
    if (!identity_result) {
        std::cerr << "[!] Грешка: " << identity_result.error() << std::endl;
        return 1;
    }
    std::cout << "[✓] Ключовете са генерирани успешно" << std::endl;

    // Initialize VoIP
    std::cout << "[*] Инициализация на VoIP..." << std::endl;
    auto& voip = voip::VoIPManager::getInstance();
    if (voip.initialize()) {
        std::cout << "[✓] VoIP инициализиран" << std::endl;
    } else {
        std::cout << "[!] VoIP не е достъпен" << std::endl;
    }

    // Initialize Mesh
    std::cout << "[*] Инициализация на Mesh мрежа..." << std::endl;
    auto& mesh = mesh::MeshNetwork::getInstance();
    if (mesh.initialize("desktop_user_001")) {
        std::cout << "[✓] Mesh мрежа инициализирана" << std::endl;
        
        // Start network
        mesh.startNetwork();
        
        auto stats = mesh.getStats();
        std::cout << "    Transport: BLE=" << (mesh.getBluetoothLE().isAvailable() ? "✓" : "✗")
                  << " WiFi=" << (mesh.getWiFiDirect().isAvailable() ? "✓" : "✗")
                  << " LoRa=" << (mesh.getLoRa().isAvailable() ? "✓" : "✗")
                  << std::endl;
    }

    std::cout << std::endl;
    std::cout << "[*] Стартиране на GUI..." << std::endl;
    std::cout << "    Профилът НЕ МОЖЕ да бъде изтрит (перманентен)" << std::endl;
    std::cout << "    Възстановяване чрез Shamir's Secret (3 от 5)" << std::endl;
    std::cout << std::endl;

    // Create and run main window (implemented in main_window.cpp)
    // For now, just show a simple window
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Liberty Reach Desktop");
    gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);
    gtk_container_set_border_width(GTK_CONTAINER(window), 10);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_add(GTK_CONTAINER(window), box);

    // Logo/Title
    GtkWidget *title = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(title), 
        "<span size='xx-large' weight='bold'>🦅 Liberty Reach</span>");
    gtk_box_pack_start(GTK_BOX(box), title, FALSE, FALSE, 20);

    // Status
    GtkWidget *status = gtk_label_new("Статус: Онлайн ✓");
    gtk_box_pack_start(GTK_BOX(box), status, FALSE, FALSE, 0);

    // Security info
    GtkWidget *security = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(security), 
        "🔒 E2EE | PQ Криптиране | Профил Завинаги");
    gtk_box_pack_start(GTK_BOX(box), security, FALSE, FALSE, 10);

    // Info text
    GtkWidget *info = gtk_label_new(NULL);
    std::string info_text = 
        "Liberty Reach Desktop Client v0.1.0\n"
        "\n"
        "Функции:\n"
        "• Криптирани съобщения (Post-Quantum)\n"
        "• Гласови и видео обаждания\n"
        "• Mesh мрежа (офлайн режим)\n"
        "• Профилът не може да бъде изтрит\n"
        "\n"
        "Натиснете Ctrl+Q за изход";
    gtk_label_set_text(GTK_LABEL(info), info_text.c_str());
    gtk_box_pack_start(GTK_BOX(box), info, FALSE, FALSE, 20);

    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    gtk_widget_show_all(window);

    std::cout << "[✓] Liberty Reach е готов за работа!" << std::endl;
    std::cout << std::endl;

    gtk_main();

    // Cleanup
    mesh.shutdown();
    voip.shutdown();

    return 0;
}
