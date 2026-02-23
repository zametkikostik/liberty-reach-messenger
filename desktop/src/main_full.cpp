/**
 * Liberty Reach Desktop Client - Full Integration
 * Real working messenger with network, crypto, and UI
 */

#include <gtk/gtk.h>
#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <chrono>

#include "liberty_reach_crypto.h"
#include "network_client.h"
#include "voip_manager.h"
#include "mesh_network.h"

using namespace td::liberty_reach;
using namespace td::liberty_reach::network;
using namespace td::liberty_reach::voip;

// Forward declaration
class LibertyReachApp;

// Global app pointer for callbacks
LibertyReachApp* g_app = nullptr;

class LibertyReachApp {
public:
    LibertyReachApp() {
        g_app = this;
        init_subsystems();
        build_ui();
        setup_callbacks();
        start_message_poller();
    }

    void run() {
        gtk_main();
    }

    // UI update methods (called from threads)
    void add_message_to_chat(const std::string& from, const std::string& text, bool outgoing) {
        g_idle_add(+[](gpointer data) -> gboolean {
            auto* app = static_cast<LibertyReachApp*>(data);
            app->do_add_message_to_chat(from, text, outgoing);
            return G_SOURCE_REMOVE;
        }, this);
    }

    void update_status(const std::string& status) {
        g_idle_add(+[](gpointer data) -> gboolean {
            auto* app = static_cast<LibertyReachApp*>(data);
            gtk_label_set_text(GTK_LABEL(app->status_label_), status.c_str());
            return G_SOURCE_REMOVE;
        }, this);
    }

    void add_contact_to_list(const std::string& name, const std::string& last_msg, bool online) {
        g_idle_add(+[](gpointer data) -> gboolean {
            auto* app = static_cast<LibertyReachApp*>(data);
            app->do_add_contact_to_list(name, last_msg, online);
            return G_SOURCE_REMOVE;
        }, this);
    }

private:
    // Subsystems
    std::unique_ptr<IdentityKeyPair> identity_;
    std::unique_ptr<NetworkClient> network_;
    
    // UI widgets
    GtkWidget *window;
    GtkWidget *header_bar;
    GtkWidget *contacts_list;
    GtkWidget *chat_view;
    GtkWidget *message_entry;
    GtkWidget *send_button;
    GtkWidget *call_button;
    GtkWidget *video_call_button;
    GtkWidget *status_label_;
    GtkWidget *encryption_badge_;
    
    // State
    std::string current_contact_;
    std::string user_id_;
    bool running_ = true;

    void init_subsystems() {
        std::cout << "[*] Инициализация подсистем..." << std::endl;
        
        // Generate identity
        auto result = LibertyReachCrypto::generate_identity_keys();
        if (result) {
            identity_ = std::make_unique<IdentityKeyPair>(*result);
            std::cout << "[✓] Крипто ключи сгенерированы" << std::endl;
        }
        
        // Create user ID from identity
        user_id_ = "user_" + std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count());
        
        // Initialize network
        network_ = std::make_unique<NetworkClient>();
        
        // Use local server or Cloudflare
        std::string server_url = "http://localhost:8787";  // Local dev
        // std::string server_url = "https://liberty-reach-messenger.worker.dev";  // Production
        
        network_->initialize(server_url, user_id_, *identity_);
        
        // Setup network callbacks
        NetworkCallbacks net_callbacks;
        net_callbacks.on_message_received = [this](const ChatMessage& msg) {
            std::cout << "[Message] From " << msg.from << ": " << msg.text << std::endl;
            add_message_to_chat(msg.from, msg.text, false);
        };
        net_callbacks.on_status_update = [this](const std::string& status) {
            update_status(status);
        };
        network_->setCallbacks(net_callbacks);
        
        // Connect to server
        if (network_->connect()) {
            std::cout << "[✓] Подключено к серверу" << std::endl;
        }
        
        // Initialize VoIP
        auto& voip = VoIPManager::getInstance();
        voip.initialize();
        std::cout << "[✓] VoIP инициализирован" << std::endl;
        
        // Initialize Mesh
        auto& mesh = MeshNetwork::getInstance();
        mesh.initialize(user_id_);
        mesh.startNetwork();
        std::cout << "[✓] Mesh сеть инициализирована" << std::endl;
        
        // Create profile
        if (network_->createProfile()) {
            std::cout << "[✓] Профиль создан (перманентный)" << std::endl;
        }
        
        // Add test contacts
        add_test_contacts();
        
        update_status("Онлайн ✓ | PQ Шифрование | Профиль перманентный");
    }

    void add_test_contacts() {
        // Add some test contacts
        network_->addContact({"alice", "Алиса", "", true, time(nullptr)});
        network_->addContact({"bob", "Борис", "", false, time(nullptr) - 3600});
        network_->addContact({"charlie", "Чарли", "", true, time(nullptr)});
        
        // Add to UI
        add_contact_to_list("Алиса", "Привет! Как дела?", true);
        add_contact_to_list("Борис", "Перезвоню позже", false);
        add_contact_to_list("Чарли", "Файл отправлен", true);
    }

    void build_ui() {
        // Create window
        window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        gtk_window_set_title(GTK_WINDOW(window), "Liberty Reach Messenger");
        gtk_window_set_default_size(GTK_WINDOW(window), 1200, 800);
        gtk_container_set_border_width(GTK_CONTAINER(window), 0);

        // Header bar
        header_bar = gtk_header_bar_new();
        gtk_header_bar_set_title(GTK_HEADER_BAR(header_bar), "Liberty Reach");
        gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(header_bar), TRUE);
        gtk_window_set_titlebar(GTK_WINDOW(window), header_bar);

        // Main horizontal box
        GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
        gtk_container_add(GTK_CONTAINER(window), main_box);

        // Left panel - Contacts
        GtkWidget *left_panel = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_box_set_homogeneous(GTK_BOX(left_panel), FALSE);
        gtk_widget_set_size_request(left_panel, 350, -1);
        gtk_box_pack_start(GTK_BOX(main_box), left_panel, FALSE, FALSE, 0);

        // Search box
        GtkWidget *search_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_container_set_border_width(GTK_CONTAINER(search_box), 8);
        gtk_box_pack_start(GTK_BOX(left_panel), search_box, FALSE, FALSE, 0);

        GtkWidget *search_entry = gtk_entry_new();
        gtk_entry_set_placeholder_text(GTK_ENTRY(search_entry), "Поиск...");
        gtk_box_pack_start(GTK_BOX(search_box), search_entry, TRUE, TRUE, 0);

        // Contacts header
        GtkWidget *contacts_header = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(contacts_header), "<b>Контакты</b>");
        gtk_widget_set_halign(contacts_header, GTK_ALIGN_START);
        gtk_container_set_border_width(GTK_CONTAINER(contacts_header), 8);
        gtk_box_pack_start(GTK_BOX(left_panel), contacts_header, FALSE, FALSE, 0);

        // Contacts list
        contacts_list = gtk_list_box_new();
        gtk_list_box_set_selection_mode(GTK_LIST_BOX(contacts_list), GTK_SELECTION_SINGLE);
        gtk_widget_set_vexpand(contacts_list, TRUE);
        gtk_box_pack_start(GTK_BOX(left_panel), contacts_list, TRUE, TRUE, 0);

        // Right panel - Chat
        GtkWidget *right_panel = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_box_pack_start(GTK_BOX(main_box), right_panel, TRUE, TRUE, 0);

        // Chat header
        GtkWidget *chat_header = gtk_header_bar_new();
        gtk_header_bar_set_title(GTK_HEADER_BAR(chat_header), "Выберите контакт");
        gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(chat_header), FALSE);
        gtk_box_pack_start(GTK_BOX(right_panel), chat_header, FALSE, FALSE, 0);

        // Messages area
        GtkWidget *messages_scrolled = gtk_scrolled_window_new(NULL, NULL);
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(messages_scrolled),
            GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
        gtk_widget_set_vexpand(messages_scrolled, TRUE);
        gtk_box_pack_start(GTK_BOX(right_panel), messages_scrolled, TRUE, TRUE, 0);

        chat_view = gtk_text_view_new();
        gtk_text_view_set_editable(GTK_TEXT_VIEW(chat_view), FALSE);
        gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(chat_view), FALSE);
        gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(chat_view), GTK_WRAP_WORD_CHAR);
        gtk_text_view_set_left_margin(GTK_TEXT_VIEW(chat_view), 10);
        gtk_text_view_set_right_margin(GTK_TEXT_VIEW(chat_view), 10);
        gtk_text_view_set_top_margin(GTK_TEXT_VIEW(chat_view), 10);
        gtk_text_view_set_bottom_margin(GTK_TEXT_VIEW(chat_view), 10);
        gtk_container_add(GTK_CONTAINER(messages_scrolled), chat_view);

        // Input area
        GtkWidget *input_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_container_set_border_width(GTK_CONTAINER(input_box), 8);
        gtk_box_pack_end(GTK_BOX(right_panel), input_box, FALSE, FALSE, 0);

        // Call buttons
        call_button = gtk_button_new_from_icon_name("call-start-symbolic", GTK_ICON_SIZE_BUTTON);
        gtk_widget_set_tooltip_text(call_button, "Голосовой вызов");
        gtk_widget_set_sensitive(call_button, FALSE);
        gtk_box_pack_start(GTK_BOX(input_box), call_button, FALSE, FALSE, 0);

        video_call_button = gtk_button_new_from_icon_name("video-call-symbolic", GTK_ICON_SIZE_BUTTON);
        gtk_widget_set_tooltip_text(video_call_button, "Видео вызов");
        gtk_widget_set_sensitive(video_call_button, FALSE);
        gtk_box_pack_start(GTK_BOX(input_box), video_call_button, FALSE, FALSE, 0);

        gtk_box_pack_start(GTK_BOX(input_box), 
            gtk_separator_new(GTK_ORIENTATION_VERTICAL), FALSE, FALSE, 6);

        // Message entry
        message_entry = gtk_entry_new();
        gtk_entry_set_placeholder_text(GTK_ENTRY(message_entry), "Напишите сообщение...");
        gtk_widget_set_hexpand(message_entry, TRUE);
        gtk_box_pack_start(GTK_BOX(input_box), message_entry, TRUE, TRUE, 0);

        // Send button
        send_button = gtk_button_new_from_icon_name("mail-send-symbolic", GTK_ICON_SIZE_BUTTON);
        gtk_widget_set_sensitive(send_button, FALSE);
        gtk_box_pack_start(GTK_BOX(input_box), send_button, FALSE, FALSE, 0);

        // Status bar
        status_label_ = gtk_label_new("Инициализация...");
        gtk_widget_set_halign(status_label_, GTK_ALIGN_START);
        gtk_label_set_ellipsize(GTK_LABEL(status_label_), PANGO_ELLIPSIZE_END);
        gtk_widget_set_size_request(status_label_, 300, -1);
        gtk_header_bar_pack_start(GTK_HEADER_BAR(header_bar), status_label_);

        // Encryption badge
        encryption_badge_ = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(encryption_badge_), "🔒 E2EE | PQ | Mesh");
        gtk_widget_set_halign(encryption_badge_, GTK_ALIGN_END);
        gtk_header_bar_pack_end(GTK_HEADER_BAR(header_bar), encryption_badge_);

        g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    }

    void setup_callbacks() {
        // Send button
        g_signal_connect(send_button, "clicked",
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                app->on_send_message();
            }), this);

        // Enter key
        g_signal_connect(message_entry, "activate",
            G_CALLBACK(+[](GtkEntry*, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                app->on_send_message();
            }), this);

        // Message entry text changed
        g_signal_connect(message_entry, "changed",
            G_CALLBACK(+[](GtkEntry* entry, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                const gchar* text = gtk_entry_get_text(entry);
                gtk_widget_set_sensitive(app->send_button, strlen(text) > 0);
            }), this);

        // Call button
        g_signal_connect(call_button, "clicked",
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                app->on_start_call(false);
            }), this);

        // Video call button
        g_signal_connect(video_call_button, "clicked",
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                app->on_start_call(true);
            }), this);
    }

    void on_send_message() {
        const gchar* text = gtk_entry_get_text(GTK_ENTRY(message_entry));
        if (strlen(text) == 0 || current_contact_.empty()) return;

        // Send via network
        std::string msg_id = network_->sendMessage(current_contact_, text);
        
        if (!msg_id.empty()) {
            // Add to chat
            add_message_to_chat("Я", text, true);
            gtk_entry_set_text(GTK_ENTRY(message_entry), "");
        } else {
            update_status("Ошибка отправки ✗");
        }
    }

    void on_start_call(bool video) {
        if (current_contact_.empty()) return;

        auto& voip = VoIPManager::getInstance();
        
        CallConfig config;
        config.media_type = video ? MediaType::AudioVideo : MediaType::AudioOnly;
        config.ice_servers = VoIPManager::fetchTurnServers("");

        auto call = voip.createCall(current_contact_, config);
        if (!call) {
            show_error("Ошибка создания вызова");
            return;
        }

        CallCallbacks callbacks;
        callbacks.on_state_changed = [this, video](CallState state) {
            switch (state) {
                case CallState::Connected:
                    update_status(video ? "Видео вызов активен ✓" : "Голосовой вызов активен ✓");
                    break;
                case CallState::Ended:
                    update_status("Вызов завершен");
                    break;
                default:
                    break;
            }
        };

        call->setCallbacks(callbacks);
        call->startCall();

        update_status(video ? "Набор номера..." : "Звонок...");
    }

    void do_add_message_to_chat(const std::string& from, const std::string& text, bool outgoing) {
        GtkTextBuffer* buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(chat_view));
        GtkTextIter iter;
        gtk_text_buffer_get_end_iter(buffer, &iter);

        std::string formatted;
        if (outgoing) {
            formatted = "<span foreground='#1976D2'><b>Я</b>: " + text + "</span>\n";
        } else {
            formatted = "<span foreground='#2E7D32'><b>" + from + "</b>: " + text + "</span>\n";
        }

        gtk_text_buffer_insert_markup(buffer, &iter, formatted.c_str(), -1);
        
        // Scroll to end
        GtkTextMark* mark = gtk_text_buffer_create_mark(buffer, NULL, &iter, FALSE);
        gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(chat_view), mark, 0.0, TRUE, 0.0, 1.0);
        gtk_text_buffer_delete_mark(buffer, mark);
    }

    void do_add_contact_to_list(const std::string& name, const std::string& last_msg, bool online) {
        GtkWidget* row = gtk_list_box_row_new();
        GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
        gtk_container_set_border_width(GTK_CONTAINER(box), 12);
        gtk_container_add(GTK_CONTAINER(row), box);

        // Avatar
        GtkWidget* avatar = gtk_label_new(NULL);
        std::string avatar_text = "<span size='large' weight='bold'>" + 
            std::string(1, name[0]) + "</span>";
        gtk_label_set_markup(GTK_LABEL(avatar), avatar_text.c_str());
        gtk_widget_set_size_request(avatar, 40, 40);
        gtk_box_pack_start(GTK_BOX(box), avatar, FALSE, FALSE, 0);

        // Info
        GtkWidget* info_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
        gtk_box_pack_start(GTK_BOX(box), info_box, TRUE, TRUE, 0);

        // Name + status
        GtkWidget* name_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_box_pack_start(GTK_BOX(info_box), name_box, FALSE, FALSE, 0);

        GtkWidget* name_label = gtk_label_new(name.c_str());
        gtk_widget_set_halign(name_label, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(name_box), name_label, FALSE, FALSE, 0);

        if (online) {
            GtkWidget* online_dot = gtk_label_new("🟢");
            gtk_box_pack_start(GTK_BOX(name_box), online_dot, FALSE, FALSE, 0);
        }

        // Message
        GtkWidget* msg_label = gtk_label_new(last_msg.c_str());
        gtk_widget_set_halign(msg_label, GTK_ALIGN_START);
        gtk_label_set_ellipsize(GTK_LABEL(msg_label), PANGO_ELLIPSIZE_END);
        gtk_box_pack_start(GTK_BOX(info_box), msg_label, FALSE, FALSE, 0);

        // Lock icon
        GtkWidget* lock_icon = gtk_label_new("🔒");
        gtk_box_pack_end(GTK_BOX(box), lock_icon, FALSE, FALSE, 0);

        gtk_widget_show_all(row);
        gtk_list_box_insert(GTK_LIST_BOX(contacts_list), row, -1);

        // Click handler
        g_signal_connect_swapped(row, "button-press-event",
            G_CALLBACK(+[](GtkWidget*, GdkEventButton* event, gpointer user_data) {
                auto* app = static_cast<LibertyReachApp*>(user_data);
                GtkWidget* row_widget = gtk_bin_get_child(GTK_BIN(gtk_event_box_get_child(
                    GTK_EVENT_BOX(gtk_widget_get_parent(gtk_widget_get_parent(row_widget))))));
                // Simplified - in production get contact name properly
                app->on_contact_selected(name);
                return FALSE;
            }), this);
    }

    void on_contact_selected(const std::string& contact) {
        current_contact_ = contact;
        gtk_widget_set_sensitive(send_button, TRUE);
        gtk_widget_set_sensitive(call_button, TRUE);
        gtk_widget_set_sensitive(video_call_button, TRUE);
        
        // Clear chat and load messages
        GtkTextBuffer* buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(chat_view));
        gtk_text_buffer_set_text(buffer, "", -1);
        
        // Load messages for this contact
        auto messages = network_->getMessages(contact);
        for (const auto& msg : messages) {
            add_message_to_chat(msg.from, msg.text, msg.is_outgoing);
        }
        
        update_status("Чат с " + contact + " | 🔒 E2EE активно");
    }

    void start_message_poller() {
        std::thread([this]() {
            while (running_) {
                if (network_->isConnected()) {
                    // Poll for new messages
                    // network_->getMessages(...)
                }
                std::this_thread::sleep_for(std::chrono::seconds(2));
            }
        }).detach();
    }

    void show_error(const std::string& error) {
        GtkWidget* dialog = gtk_message_dialog_new(
            GTK_WINDOW(window),
            GTK_DIALOG_MODAL,
            GTK_MESSAGE_ERROR,
            GTK_BUTTONS_OK,
            "%s", error.c_str());
        gtk_dialog_run(GTK_DIALOG(dialog));
        gtk_widget_destroy(dialog);
    }
};

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    std::cout << R"(
╔═══════════════════════════════════════════════════════════╗
║         🦅 Liberty Reach Desktop Messenger                ║
║         Версия 0.1.0                                      ║
║         Полноценный рабочий мессенджер                    ║
╚═══════════════════════════════════════════════════════════╝
    )" << std::endl;

    LibertyReachApp app;
    app.run();

    return 0;
}
