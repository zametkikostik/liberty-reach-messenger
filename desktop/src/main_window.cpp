/**
 * Liberty Reach Desktop Client - Main Window
 */

#include <gtk/gtk.h>
#include <string>
#include <vector>
#include <memory>

#include "liberty_reach_crypto.h"
#include "voip_manager.h"
#include "mesh_network.h"

using namespace td::liberty_reach;

class MainWindow {
public:
    MainWindow() {
        init_crypto();
        build_ui();
        setup_callbacks();
    }

    void run() {
        gtk_main();
    }

private:
    // Main widgets
    GtkWidget *window;
    GtkWidget *header_bar;
    GtkWidget *chat_list;
    GtkWidget *chat_view;
    GtkWidget *message_entry;
    GtkWidget *send_button;
    GtkWidget *call_button;
    GtkWidget *video_call_button;
    GtkWidget *status_label;
    
    // Crypto
    std::unique_ptr<IdentityKeyPair> identity;
    std::unique_ptr<SessionKeys> session;

    void init_crypto() {
        // Generate identity keys
        auto result = LibertyReachCrypto::generate_identity_keys();
        if (result) {
            identity = std::make_unique<IdentityKeyPair>(*result);
            update_status("Криптография инициализирана ✓");
        } else {
            update_status("Грешка при инициализация на криптографията");
        }
    }

    void build_ui() {
        // Create window
        window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        gtk_window_set_title(GTK_WINDOW(window), "Liberty Reach");
        gtk_window_set_default_size(GTK_WINDOW(window), 1200, 800);
        gtk_container_set_border_width(GTK_CONTAINER(window), 0);

        // Header bar
        header_bar = gtk_header_bar_new();
        gtk_header_bar_set_title(GTK_HEADER_BAR(header_bar), "Liberty Reach");
        gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(header_bar), TRUE);
        gtk_window_set_titlebar(GTK_WINDOW(window), header_bar);

        // Create main box
        GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
        gtk_container_add(GTK_CONTAINER(window), main_box);

        // Left panel - Chat list
        GtkWidget *left_panel = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_box_set_homogeneous(GTK_BOX(left_panel), FALSE);
        gtk_widget_set_size_request(left_panel, 350, -1);
        gtk_box_pack_start(GTK_BOX(main_box), left_panel, FALSE, FALSE, 0);

        // Chat list header
        GtkWidget *chat_header = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(chat_header), 
            "<b>Чатове</b>");
        gtk_widget_set_halign(chat_header, GTK_ALIGN_START);
        gtk_widget_set_valign(chat_header, GTK_ALIGN_CENTER);
        gtk_container_set_border_width(GTK_CONTAINER(chat_header), 12);
        gtk_box_pack_start(GTK_BOX(left_panel), chat_header, FALSE, FALSE, 0);

        // Chat list (ListBox)
        chat_list = gtk_list_box_new();
        gtk_list_box_set_selection_mode(GTK_LIST_BOX(chat_list), 
            GTK_SELECTION_SINGLE);
        gtk_widget_set_vexpand(chat_list, TRUE);
        gtk_box_pack_start(GTK_BOX(left_panel), chat_list, TRUE, TRUE, 0);

        // Add sample chats
        add_chat_item("Test User", "Hello! Това е криптирано съобщение.", "10:30", 2);
        add_chat_item("Борис", "Виждаш ли ме?", "09:15", 0);
        add_chat_item("Алиса", "Гласовото съобщение е изпратено", "Вчера", 1);

        // Right panel - Chat view
        GtkWidget *right_panel = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_box_pack_start(GTK_BOX(main_box), right_panel, TRUE, TRUE, 0);

        // Messages area (ScrolledWindow + TextView)
        GtkWidget *messages_scrolled = gtk_scrolled_window_new(NULL, NULL);
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(messages_scrolled),
            GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
        gtk_widget_set_vexpand(messages_scrolled, TRUE);
        gtk_box_pack_start(GTK_BOX(right_panel), messages_scrolled, TRUE, TRUE, 0);

        chat_view = gtk_text_view_new();
        gtk_text_view_set_editable(GTK_TEXT_VIEW(chat_view), FALSE);
        gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(chat_view), FALSE);
        gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(chat_view), GTK_WRAP_WORD_CHAR);
        gtk_container_add(GTK_CONTAINER(messages_scrolled), chat_view);

        // Add sample messages
        add_message("Test User", "Здрасти! Как си?", FALSE);
        add_message("Аз", "Добре съм, благодаря! Ти?", TRUE);
        add_message("Test User", "Супер! Liberty Reach работи перфектно!", FALSE);

        // Input area
        GtkWidget *input_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_container_set_border_width(GTK_CONTAINER(input_box), 12);
        gtk_box_pack_end(GTK_BOX(right_panel), input_box, FALSE, FALSE, 0);

        // Call buttons
        call_button = gtk_button_new_from_icon_name("call-start-symbolic", 
            GTK_ICON_SIZE_BUTTON);
        gtk_widget_set_tooltip_text(call_button, "Гласово обаждане");
        gtk_box_pack_start(GTK_BOX(input_box), call_button, FALSE, FALSE, 0);

        video_call_button = gtk_button_new_from_icon_name("video-call-symbolic", 
            GTK_ICON_SIZE_BUTTON);
        gtk_widget_set_tooltip_text(video_call_button, "Видео обаждане");
        gtk_box_pack_start(GTK_BOX(input_box), video_call_button, FALSE, FALSE, 0);

        gtk_box_pack_start(GTK_BOX(input_box), 
            gtk_separator_new(GTK_ORIENTATION_VERTICAL), FALSE, FALSE, 6);

        // Message entry
        message_entry = gtk_entry_new();
        gtk_entry_set_placeholder_text(GTK_ENTRY(message_entry), 
            "Напишете съобщение...");
        gtk_widget_set_hexpand(message_entry, TRUE);
        gtk_box_pack_start(GTK_BOX(input_box), message_entry, TRUE, TRUE, 0);

        // Send button
        send_button = gtk_button_new_from_icon_name("mail-send-symbolic", 
            GTK_ICON_SIZE_BUTTON);
        gtk_box_pack_start(GTK_BOX(input_box), send_button, FALSE, FALSE, 0);

        // Status bar
        status_label = gtk_label_new("Инициализация...");
        gtk_widget_set_halign(status_label, GTK_ALIGN_START);
        gtk_label_set_ellipsize(GTK_LABEL(status_label), PANGO_ELLIPSIZE_END);
        gtk_widget_set_size_request(status_label, 200, -1);
        gtk_header_bar_pack_start(GTK_HEADER_BAR(header_bar), status_label);

        // Security badge
        GtkWidget *security_badge = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(security_badge), 
            "🔒 E2EE | PQ Криптиране");
        gtk_widget_set_halign(security_badge, GTK_ALIGN_END);
        gtk_header_bar_pack_end(GTK_HEADER_BAR(header_bar), security_badge);

        g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    }

    void setup_callbacks() {
        // Send button
        g_signal_connect(send_button, "clicked", 
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                MainWindow* self = static_cast<MainWindow*>(user_data);
                self->on_send_message();
            }), this);

        // Enter key in message entry
        g_signal_connect(message_entry, "activate", 
            G_CALLBACK(+[](GtkEntry*, gpointer user_data) {
                MainWindow* self = static_cast<MainWindow*>(user_data);
                self->on_send_message();
            }), this);

        // Call button
        g_signal_connect(call_button, "clicked", 
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                MainWindow* self = static_cast<MainWindow*>(user_data);
                self->on_start_call(false);
            }), this);

        // Video call button
        g_signal_connect(video_call_button, "clicked", 
            G_CALLBACK(+[](GtkWidget*, gpointer user_data) {
                MainWindow* self = static_cast<MainWindow*>(user_data);
                self->on_start_call(true);
            }), this);
    }

    void add_chat_item(const std::string& name, const std::string& last_message,
                       const std::string& time, int unread) {
        GtkWidget *row = gtk_list_box_row_new();
        GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
        gtk_container_set_border_width(GTK_CONTAINER(box), 12);
        gtk_container_add(GTK_CONTAINER(row), box);

        // Avatar
        GtkWidget *avatar = gtk_label_new(NULL);
        std::string avatar_text = "<b>" + std::string(1, name[0]) + "</b>";
        gtk_label_set_markup(GTK_LABEL(avatar), avatar_text.c_str());
        gtk_widget_set_size_request(avatar, 40, 40);
        gtk_box_pack_start(GTK_BOX(box), avatar, FALSE, FALSE, 0);

        // Info
        GtkWidget *info_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
        gtk_box_pack_start(GTK_BOX(box), info_box, TRUE, TRUE, 0);

        // Name + time
        GtkWidget *name_time_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_box_pack_start(GTK_BOX(info_box), name_time_box, FALSE, FALSE, 0);

        GtkWidget *name_label = gtk_label_new(name.c_str());
        gtk_widget_set_halign(name_label, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(name_time_box), name_label, FALSE, FALSE, 0);

        GtkWidget *time_label = gtk_label_new(time.c_str());
        gtk_label_set_attributes(GTK_LABEL(time_label), 
            pango_attr_list_new()); // Smaller font
        gtk_box_pack_end(GTK_BOX(name_time_box), time_label, FALSE, FALSE, 0);

        // Message
        GtkWidget *msg_label = gtk_label_new(last_message.c_str());
        gtk_widget_set_halign(msg_label, GTK_ALIGN_START);
        gtk_label_set_ellipsize(GTK_LABEL(msg_label), PANGO_ELLIPSIZE_END);
        gtk_box_pack_start(GTK_BOX(info_box), msg_label, FALSE, FALSE, 0);

        // Unread badge
        if (unread > 0) {
            GtkWidget *badge = gtk_label_new(NULL);
            std::string badge_text = "<span bgcolor='#1976D2' fgcolor='white'> " + 
                std::to_string(unread) + " </span>";
            gtk_label_set_markup(GTK_LABEL(badge), badge_text.c_str());
            gtk_box_pack_end(GTK_BOX(box), badge, FALSE, FALSE, 0);
        }

        // Lock icon
        GtkWidget *lock_icon = gtk_label_new("🔒");
        gtk_box_pack_end(GTK_BOX(box), lock_icon, FALSE, FALSE, 0);

        gtk_widget_show_all(row);
        gtk_list_box_insert(GTK_LIST_BOX(chat_list), row, -1);
    }

    void add_message(const std::string& sender, const std::string& text, 
                     bool is_outgoing) {
        GtkTextBuffer *buffer = gtk_text_view_get_buffer(
            GTK_TEXT_VIEW(chat_view));
        GtkTextIter iter;
        gtk_text_buffer_get_end_iter(buffer, &iter);

        std::string formatted;
        if (is_outgoing) {
            formatted = "<b>Аз</b>: " + text + "\n";
        } else {
            formatted = "<b>" + sender + "</b>: " + text + "\n";
        }

        gtk_text_buffer_insert_markup(buffer, &iter, formatted.c_str(), -1);
        
        // Scroll to end
        GtkTextMark *mark = gtk_text_buffer_create_mark(buffer, NULL, &iter, FALSE);
        gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(chat_view), mark, 0.0, 
            TRUE, 0.0, 1.0);
        gtk_text_buffer_delete_mark(buffer, mark);
    }

    void on_send_message() {
        const gchar *text = gtk_entry_get_text(GTK_ENTRY(message_entry));
        if (strlen(text) == 0) return;

        // Add message to chat
        add_message("Аз", text, TRUE);

        // In production: Encrypt and send via network
        // For now, just clear entry
        gtk_entry_set_text(GTK_ENTRY(message_entry), "");

        update_status("Съобщението е изпратено ✓");
    }

    void on_start_call(bool video) {
        using namespace td::liberty_reach::voip;
        
        auto& voip = VoIPManager::getInstance();
        if (!voip.initialize()) {
            show_error("Грешка при инициализация на VoIP");
            return;
        }

        CallConfig config;
        config.media_type = video ? MediaType::AudioVideo : MediaType::AudioOnly;
        config.ice_servers = VoIPManager::fetchTurnServers(
            "https://turn.libertyreach.internal");

        auto call = voip.createCall("callee_id", config);
        if (!call) {
            show_error("Грешка при създаване на обаждане");
            return;
        }

        CallCallbacks callbacks;
        callbacks.on_state_changed = [this](CallState state) {
            switch (state) {
                case CallState::Connected:
                    update_status("Обаждането е свързано ✓");
                    break;
                case CallState::Ended:
                    update_status("Обаждането приключи");
                    break;
                default:
                    break;
            }
        };

        call->setCallbacks(callbacks);
        call->startCall();

        update_status(video ? "Видео обаждане..." : "Гласово обаждане...");
    }

    void update_status(const std::string& status) {
        gtk_label_set_text(GTK_LABEL(status_label), status.c_str());
    }

    void show_error(const std::string& error) {
        GtkWidget *dialog = gtk_message_dialog_new(
            GTK_WINDOW(window),
            GTK_DIALOG_MODAL,
            GTK_MESSAGE_ERROR,
            GTK_BUTTONS_OK,
            "%s", error.c_str());
        gtk_dialog_run(GTK_DIALOG(dialog));
        gtk_widget_destroy(dialog);
    }
};

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    MainWindow app;
    app.run();

    return 0;
}
