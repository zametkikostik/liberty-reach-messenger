#!/usr/bin/env python3
"""
Liberty Reach Desktop Client
GTK3 GUI за мессенджера
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import hashlib
import secrets
from datetime import datetime
import json
import os

# CSS Styles
CSS = b"""
window {
    background: #f4f4f5;
}

.sidebar {
    background: #ffffff;
    border-right: 1px solid #dfe1e5;
}

.chat-list row {
    padding: 10px;
    margin: 2px 0;
}

.chat-list row:hover {
    background: #f4f4f5;
}

.chat-list row:selected {
    background: #3390ec20;
}

.message-bubble {
    border-radius: 12px;
    padding: 8px 12px;
    margin: 4px;
}

.message-in {
    background: #ffffff;
}

.message-out {
    background: #eeffde;
}

.header-bar {
    background: #ffffff;
    border-bottom: 1px solid #dfe1e5;
}

.search-entry {
    border-radius: 22px;
    background: #f4f4f5;
}

.send-button {
    background: #3390ec;
    color: white;
    border-radius: 50%;
    min-width: 40px;
    min-height: 40px;
}

.send-button:hover {
    background: #2878c0;
}
"""

class Message:
    def __init__(self, text, from_me=True):
        self.text = text
        self.from_me = from_me
        self.time = datetime.now()
        self.id = secrets.token_hex(8)

class Chat:
    def __init__(self, name, avatar="👤"):
        self.name = name
        self.avatar = avatar
        self.messages = []
        self.last_seen = datetime.now()
        self.unread = 0
        
    def add_message(self, text, from_me=False):
        msg = Message(text, from_me)
        self.messages.append(msg)
        self.last_seen = msg.time
        if not from_me:
            self.unread += 1
        return msg

class ChatRow(Gtk.ListBoxRow):
    def __init__(self, chat):
        super().__init__()
        self.chat = chat
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(8)
        hbox.set_margin_bottom(8)
        
        # Avatar
        avatar = Gtk.Label()
        avatar.set_markup(f"<span size='xx-large'>{chat.avatar}</span>")
        avatar.set_size_request(50, 50)
        hbox.pack_start(avatar, False, False, 0)
        
        # Info
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_hexpand(True)
        
        name = Gtk.Label()
        name.set_markup(f"<b>{chat.name}</b>")
        name.set_halign(Gtk.Align.START)
        vbox.pack_start(name, False, False, 0)
        
        last_msg = Gtk.Label()
        last_msg.set_ellipsize(Pango.EllipsizeMode.END)
        last_msg.set_max_width_chars(25)
        if chat.messages:
            last_msg.set_text(chat.messages[-1].text[:40])
        last_msg.get_style_context().add_class('dim-label')
        vbox.pack_start(last_msg, False, False, 0)
        
        hbox.pack_start(vbox, True, True, 0)
        
        # Time
        time_label = Gtk.Label()
        time_label.set_text(chat.last_seen.strftime("%H:%M"))
        time_label.get_style_context().add_class('dim-label')
        hbox.pack_start(time_label, False, False, 0)
        
        self.add(hbox)
        self.show_all()

class MessageBubble(Gtk.Box):
    def __init__(self, message):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.set_margin_start(10)
        self.set_margin_end(10)
        self.set_margin_top(4)
        self.set_margin_bottom(4)
        
        if message.from_me:
            self.set_halign(Gtk.Align.END)
            self.get_style_context().add_class('message-out')
        else:
            self.set_halign(Gtk.Align.START)
            self.get_style_context().add_class('message-in')
        
        self.get_style_context().add_class('message-bubble')
        
        # Text
        text = Gtk.Label()
        text.set_markup(message.text)
        text.set_line_wrap(True)
        text.set_max_width_chars(50)
        text.set_xalign(0 if not message.from_me else 1)
        self.pack_start(text, False, False, 4)
        
        # Time
        time = Gtk.Label()
        time.set_text(message.time.strftime("%H:%M"))
        time.get_style_context().add_class('dim-label')
        if message.from_me:
            time.set_xalign(1)
        else:
            time.set_xalign(0)
        self.pack_start(time, False, False, 2)
        
        self.show_all()

class MainWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="🦅 Liberty Reach Messenger")
        self.set_default_size(1200, 800)
        self.set_border_width(0)
        
        # Load CSS
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
        # State
        self.current_chat = None
        self.chats = []
        
        # Initialize demo chats
        self.init_demo_chats()
        
        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.add(main_box)
        
        # Sidebar
        self.sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.sidebar.set_size_request(350, -1)
        self.sidebar.get_style_context().add_class('sidebar')
        main_box.pack_start(self.sidebar, False, False, 0)
        
        # Header
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.props.title = "🦅 Liberty Reach"
        
        search = Gtk.Entry()
        search.set_placeholder_text("Поиск...")
        search.set_size_request(200, -1)
        search.get_style_context().add_class('search-entry')
        search.connect("changed", self.on_search_changed)
        header.pack_start(search)
        
        self.sidebar.pack_start(header, False, False, 0)
        
        # Chat list
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.chat_list = Gtk.ListBox()
        self.chat_list.get_style_context().add_class('chat-list')
        self.chat_list.connect("row-activated", self.on_chat_selected)
        scroll.add(self.chat_list)
        self.sidebar.pack_start(scroll, True, True, 0)
        
        self.render_chat_list()
        
        # Main chat area
        chat_area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        main_box.pack_start(chat_area, True, True, 0)
        
        # Chat header
        chat_header = Gtk.HeaderBar()
        chat_header.get_style_context().add_class('header-bar')
        
        self.header_title = Gtk.Label()
        self.header_title.set_markup("<b>Изберете чат</b>")
        chat_header.set_custom_title(self.header_title)
        
        chat_area.pack_start(chat_header, False, False, 0)
        
        # Messages
        messages_scroll = Gtk.ScrolledWindow()
        messages_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.messages_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.messages_box.set_margin_top(10)
        self.messages_box.set_margin_bottom(10)
        messages_scroll.add(self.messages_box)
        chat_area.pack_start(messages_scroll, True, True, 0)
        
        # Input area
        input_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        input_box.set_margin_start(10)
        input_box.set_margin_end(10)
        input_box.set_margin_top(10)
        input_box.set_margin_bottom(10)
        input_box.set_spacing(10)
        
        self.message_input = Gtk.Entry()
        self.message_input.set_placeholder_text("Написать сообщение...")
        self.message_input.connect("activate", self.on_send)
        input_box.pack_start(self.message_input, True, True, 0)
        
        send_btn = Gtk.Button()
        send_btn.set_label("➤")
        send_btn.get_style_context().add_class('send-button')
        send_btn.connect("clicked", self.on_send)
        input_box.pack_start(send_btn, False, False, 0)
        
        chat_area.pack_start(input_box, False, False, 0)
        
        self.show_all()
    
    def init_demo_chats(self):
        chat1 = Chat("Павел Дуров", "👨")
        chat1.add_message("Добро пожаловать в Liberty Reach! 🦅", from_me=False)
        chat1.add_message("Это самый безопасный мессенджер с Post-Quantum шифрованием!", from_me=False)
        
        chat2 = Chat("Илон Маск", "👨‍🚀")
        chat2.add_message("Когда на Марс полетим? 🚀", from_me=False)
        
        chat3 = Chat("Liberty Reach News", "📰")
        chat3.add_message("Обновление v0.1.0 доступно!", from_me=False)
        
        chat4 = Chat("Crypto Chat", "💰")
        chat4.add_message("BTC: $95,432 (+2.3%)", from_me=False)
        
        self.chats = [chat1, chat2, chat3, chat4]
    
    def render_chat_list(self):
        self.chat_list.foreach(lambda w: w.destroy())
        for chat in sorted(self.chats, key=lambda c: c.last_seen, reverse=True):
            row = ChatRow(chat)
            self.chat_list.add(row)
        self.chat_list.show_all()
    
    def render_messages(self):
        self.messages_box.foreach(lambda w: w.destroy())
        if self.current_chat:
            for msg in self.current_chat.messages:
                bubble = MessageBubble(msg)
                self.messages_box.pack_start(bubble, False, False, 0)
            self.messages_box.show_all()
    
    def on_chat_selected(self, listbox, row):
        if row:
            self.current_chat = row.chat
            self.current_chat.unread = 0
            self.header_title.set_markup(f"<b>{row.chat.name}</b>  <span size='small'>в сети</span>")
            self.render_messages()
            self.render_chat_list()
    
    def on_send(self, widget):
        text = self.message_input.get_text().strip()
        if text and self.current_chat:
            self.current_chat.add_message(text, from_me=True)
            self.message_input.set_text("")
            self.render_messages()
            self.render_chat_list()
            
            # Scroll to bottom
            adj = self.messages_box.get_parent().get_vadjustment()
            adj.set_value(adj.get_upper() - adj.get_page_size())
            
            # Simulate reply
            GLib.timeout_add(1000 + secrets.randbelow(2000), self.simulate_reply)
    
    def simulate_reply(self):
        if self.current_chat:
            replies = [
                "Интересно! 🤔",
                "Согласен!",
                "Круто! 🔥",
                "Да, конечно!",
                "👍",
                "Ха-ха! 😄",
                "Серьезно?",
                "🦅 Liberty Reach!"
            ]
            reply = secrets.choice(replies)
            self.current_chat.add_message(reply, from_me=False)
            self.render_messages()
            self.render_chat_list()
        return False
    
    def on_search_changed(self, entry):
        text = entry.get_text().lower()
        self.chat_list.foreach(lambda row: row.destroy())
        for chat in self.chats:
            if text in chat.name.lower():
                row = ChatRow(chat)
                self.chat_list.add(row)
        self.chat_list.show_all()

def main():
    win = MainWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
