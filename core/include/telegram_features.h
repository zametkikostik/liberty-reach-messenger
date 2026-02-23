/**
 * Liberty Reach - Telegram-like Features
 * Channels, Bots, Stickers, Stories
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace features {

// ============================================
// CHANNELS
// ============================================

/**
 * Channel type
 */
enum class ChannelType {
    PUBLIC,     // Anyone can join
    PRIVATE,    // Invite only
    BROADCAST   // Admins only post
};

/**
 * Channel structure
 */
struct Channel {
    std::string id;
    std::string name;
    std::string description;
    std::string username;  // @username
    ChannelType type;
    int subscribers_count = 0;
    std::string photo_url;
    bool is_verified = false;
    bool is_scam = false;
    bool is_fake = false;
    int64_t created_at = 0;
    std::string creator_id;
    std::string invite_link;
};

/**
 * Channel member
 */
struct ChannelMember {
    std::string user_id;
    std::string role;  // "creator", "admin", "member"
    int64_t joined_at = 0;
    bool can_post = false;
    bool can_edit = false;
    bool can_delete = false;
};

/**
 * Channel post
 */
struct ChannelPost {
    std::string id;
    std::string channel_id;
    std::string author_id;
    std::string text;
    std::vector<std::string> media_urls;
    int64_t timestamp = 0;
    int views_count = 0;
    int forwards_count = 0;
    int reactions_count = 0;
    std::map<std::string, int> reactions;  // emoji -> count
    bool is_pinned = false;
    bool is_edited = false;
};

// ============================================
// BOTS
// ============================================

/**
 * Bot structure
 */
struct Bot {
    std::string id;
    std::string name;
    std::string username;  // @botname
    std::string description;
    std::string photo_url;
    std::string token;
    std::string webhook_url;
    bool is_verified = false;
    bool can_join_groups = true;
    bool can_read_all_group_messages = false;
    bool supports_inline_queries = false;
    std::vector<std::string> commands;
};

/**
 * Bot command
 */
struct BotCommand {
    std::string command;
    std::string description;
};

/**
 * Inline query result
 */
struct InlineQueryResult {
    std::string id;
    std::string type;  // "article", "photo", "video", etc.
    std::string title;
    std::string description;
    std::string url;
    std::string thumb_url;
};

/**
 * Bot callback
 */
struct BotCallback {
    std::string callback_id;
    std::string message_id;
    std::string data;
    std::string from_user_id;
};

// ============================================
// STICKERS
// ============================================

/**
 * Sticker structure
 */
struct Sticker {
    std::string id;
    std::string file_id;
    std::string file_url;
    std::string emoji;
    int width = 512;
    int height = 512;
    bool is_animated = false;
    bool is_video = false;
    std::string thumbnail_url;
};

/**
 * Sticker pack
 */
struct StickerPack {
    std::string id;
    std::string name;
    std::string title;
    std::vector<Sticker> stickers;
    std::string thumbnail_url;
    bool is_official = false;
    int installed_count = 0;
};

/**
 * Mask position for stickers
 */
struct MaskPosition {
    std::string point;  // "forehead", "eyes", "mouth", "chin"
    double x_shift = 0.0;
    double y_shift = 0.0;
    double scale = 1.0;
};

// ============================================
// STORIES
// ============================================

/**
 * Story structure
 */
struct Story {
    std::string id;
    std::string user_id;
    std::string media_url;
    std::string caption;
    int64_t created_at = 0;
    int64_t expires_at = 0;  // 24 hours from creation
    int views_count = 0;
    bool has_audio = false;
    int duration_seconds = 0;
};

// ============================================
// REACTIONS
// ============================================

/**
 * Message reaction
 */
struct Reaction {
    std::string emoji;
    int count = 0;
    bool is_selected = false;
    std::vector<std::string> recent_user_ids;
};

// ============================================
// FOLDERS
// ============================================

/**
 * Chat folder
 */
struct ChatFolder {
    std::string id;
    std::string title;
    std::vector<std::string> chat_ids;
    std::vector<std::string> channel_ids;
    bool include_muted = false;
    bool include_read = false;
    bool include_archived = false;
    std::string icon_emoji;
};

// ============================================
// FEATURES MANAGER
// ============================================

/**
 * Features Manager - Main class
 */
class FeaturesManager {
public:
    static FeaturesManager& getInstance();

    // ============================================
    // CHANNELS
    // ============================================

    /**
     * Create channel
     */
    Channel createChannel(
        const std::string& name,
        const std::string& description,
        ChannelType type);

    /**
     * Get channel info
     */
    Channel getChannel(const std::string& channel_id);

    /**
     * Get channel list
     */
    std::vector<Channel> getChannels() const;

    /**
     * Subscribe to channel
     */
    bool subscribeToChannel(const std::string& channel_id);

    /**
     * Unsubscribe from channel
     */
    bool unsubscribeFromChannel(const std::string& channel_id);

    /**
     * Post to channel
     */
    ChannelPost postToChannel(
        const std::string& channel_id,
        const std::string& text,
        const std::vector<std::string>& media_urls = {});

    /**
     * Get channel posts
     */
    std::vector<ChannelPost> getChannelPosts(const std::string& channel_id, int limit = 50);

    /**
     * Delete channel post
     */
    bool deleteChannelPost(const std::string& channel_id, const std::string& post_id);

    /**
     * Get channel members
     */
    std::vector<ChannelMember> getChannelMembers(const std::string& channel_id);

    /**
     * Add channel admin
     */
    bool addChannelAdmin(const std::string& channel_id, const std::string& user_id);

    // ============================================
    // BOTS
    // ============================================

    /**
     * Create bot
     */
    Bot createBot(
        const std::string& name,
        const std::string& token);

    /**
     * Get bot info
     */
    Bot getBot(const std::string& bot_id);

    /**
     * Get bot commands
     */
    std::vector<BotCommand> getBotCommands(const std::string& bot_id);

    /**
     * Set bot commands
     */
    bool setBotCommands(const std::string& bot_id, const std::vector<BotCommand>& commands);

    /**
     * Handle bot message
     */
    std::string handleBotMessage(const std::string& bot_id, const std::string& message);

    /**
     * Send bot response
     */
    bool sendBotResponse(const std::string& bot_id, const std::string& to_user, const std::string& text);

    // ============================================
    // STICKERS
    // ============================================

    /**
     * Create sticker pack
     */
    StickerPack createStickerPack(const std::string& name, const std::string& title);

    /**
     * Add sticker to pack
     */
    bool addStickerToPack(const std::string& pack_id, const Sticker& sticker);

    /**
     * Get sticker packs
     */
    std::vector<StickerPack> getStickerPacks() const;

    /**
     * Get sticker pack
     */
    StickerPack getStickerPack(const std::string& pack_id);

    /**
     * Install sticker pack
     */
    bool installStickerPack(const std::string& pack_id);

    /**
     * Get installed sticker packs
     */
    std::vector<StickerPack> getInstalledStickerPacks() const;

    /**
     * Get trending sticker packs
     */
    std::vector<StickerPack> getTrendingStickerPacks();

    /**
     * Search stickers by emoji
     */
    std::vector<Sticker> searchStickers(const std::string& emoji);

    // ============================================
    // STORIES
    // ============================================

    /**
     * Create story
     */
    Story createStory(
        const std::string& media_url,
        const std::string& caption = "",
        int duration_seconds = 15);

    /**
     * Get stories
     */
    std::vector<Story> getStories(const std::string& user_id = "");

    /**
     * View story
     */
    bool viewStory(const std::string& story_id);

    /**
     * Delete story
     */
    bool deleteStory(const std::string& story_id);

    // ============================================
    // REACTIONS
    // ============================================

    /**
     * Add reaction to message
     */
    bool addReaction(const std::string& message_id, const std::string& emoji);

    /**
     * Remove reaction from message
     */
    bool removeReaction(const std::string& message_id, const std::string& emoji);

    /**
     * Get message reactions
     */
    std::vector<Reaction> getMessageReactions(const std::string& message_id);

    // ============================================
    // FOLDERS
    // ============================================

    /**
     * Create chat folder
     */
    ChatFolder createFolder(const std::string& title);

    /**
     * Get folders
     */
    std::vector<ChatFolder> getFolders() const;

    /**
     * Update folder
     */
    bool updateFolder(const ChatFolder& folder);

    /**
     * Delete folder
     */
    bool deleteFolder(const std::string& folder_id);

private:
    FeaturesManager() = default;
    ~FeaturesManager() = default;
    FeaturesManager(const FeaturesManager&) = delete;
    FeaturesManager& operator=(const FeaturesManager&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace features
} // namespace liberty_reach
} // namespace td
