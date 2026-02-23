/**
 * Liberty Reach - Family Statuses System
 * Семейные статусы и отношения
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>

namespace td {
namespace liberty_reach {
namespace features {

// ============================================
// FAMILY STATUS TYPES
// ============================================

/**
 * Relationship status
 */
enum class RelationshipStatus {
    SINGLE,              // Не женат/не замужем
    IN_RELATIONSHIP,     // В отношениях
    ENGAGED,            // Помолвлен(а)
    MARRIED,            // Женат/замужем
    IN_CIVIL_UNION,     // Гражданский брак
    SEPARATED,          // Раздельно проживаем
    DIVORCED,           // Разведен(а)
    WIDOWED,            // Вдовец/вдова
    ITS_COMPLEX,        // Всё сложно
    IN_OPEN_RELATIONSHIP, // Открытые отношения
    PREFER_NOT_TO_SAY   // Предпочитаю не говорить
};

/**
 * Family role
 */
enum class FamilyRole {
    NONE,               // Без роли
    FATHER,             // Отец
    MOTHER,             // Мать
    SON,                // Сын
    DAUGHTER,           // Дочь
    BROTHER,            // Брат
    SISTER,             // Сестра
    GRANDFATHER,        // Дедушка
    GRANDMOTHER,        // Бабушка
    GRANDSON,           // Внук
    GRANDDAUGHTER,      // Внучка
    UNCLE,              // Дядя
    AUNT,               // Тетя
    NEPHEW,             // Племянник
    NIECE,              // Племянница
    COUSIN,             // Двоюродный брат/сестра
    HUSBAND,            // Муж
    WIFE,               // Жена
    PARTNER,            // Партнер
    STEP_FATHER,        // Отчим
    STEP_MOTHER,        // Мачеха
    STEP_SON,           // Пасынок
    STEP_DAUGHTER,      // Падчерица
    ADOPTIVE_FATHER,    // Приемный отец
    ADOPTIVE_MOTHER,    // Приемная мать
    FOSTER_FATHER,      // Опекун
    FOSTER_MOTHER       // Опекунша
};

/**
 * Children status
 */
enum class ChildrenStatus {
    NO_CHILDREN,        // Нет детей
    HAS_CHILDREN,       // Есть дети
    EXPECTING,          // Ожидаю ребенка
    PLANNING,           // Планирую детей
    DOESNT_WANT,        // Не хочу детей
    PREFER_NOT_TO_SAY   // Предпочитаю не говорить
};

/**
 * Family information structure
 */
struct FamilyInfo {
    std::string user_id;
    RelationshipStatus relationship_status = RelationshipStatus::PREFER_NOT_TO_SAY;
    ChildrenStatus children_status = ChildrenStatus::PREFER_NOT_TO_SAY;
    FamilyRole family_role = FamilyRole::NONE;
    
    // Partner info (if in relationship)
    std::string partner_user_id;
    std::string partner_name;
    bool partner_public = false;  // Показывать ли партнера публично
    
    // Children info
    int children_count = 0;
    std::vector<std::string> children_user_ids;
    
    // Family members
    std::map<std::string, FamilyRole> family_members;  // user_id -> role
    
    // Privacy settings
    bool show_relationship_status = true;
    bool show_children_status = true;
    bool show_family_members = true;
    
    // Anniversary dates
    int64_t relationship_started_at = 0;
    int64_t married_at = 0;
    int64_t anniversary_date = 0;  // День годовщины
    
    // Custom status text
    std::string custom_status;
    
    // Status emoji
    std::string status_emoji;
    
    // Last updated
    int64_t updated_at = 0;
};

/**
 * Family event types
 */
enum class FamilyEventType {
    WEDDING,            // Свадьба
    ENGAGEMENT,         // Помолвка
    BIRTHDAY,           // День рождения
    ANNIVERSARY,        // Годовщина
    BABY_SHOWER,        // Рождение ребенка
    GRADUATION,         // Выпускной
    FAMILY_REUNION,     // Семейное собрание
    MEMORIAL,           // Поминальная служба
    VACATION,           // Семейный отпуск
    OTHER               // Другое
};

/**
 * Family event structure
 */
struct FamilyEvent {
    std::string id;
    std::string family_id;
    std::string title;
    std::string description;
    FamilyEventType type;
    int64_t event_date = 0;
    int64_t created_at = 0;
    std::string location;
    std::vector<std::string> invited_users;
    std::vector<std::string> photos;
    bool is_private = false;
    bool is_recurring = false;
    std::string recurrence_pattern;  // "yearly", "monthly", "weekly"
};

/**
 * Family tree node
 */
struct FamilyTreeNode {
    std::string user_id;
    std::string name;
    std::string photo_url;
    FamilyRole role;
    int age = 0;
    std::string birth_date;
    bool is_alive = true;
    
    std::vector<FamilyTreeNode> children;
    std::vector<FamilyTreeNode> parents;
    std::vector<FamilyTreeNode> siblings;
    std::string spouse_user_id;
};

/**
 * Family status display configuration
 */
struct FamilyStatusDisplay {
    bool show_on_profile = true;
    bool show_in_chat = true;
    bool show_status_emoji = true;
    bool show_partner = true;
    bool show_children = true;
    bool show_anniversary = true;
    std::string display_style = "default";  // "default", "minimal", "detailed"
};

// ============================================
// FAMILY MANAGER
// ============================================

/**
 * Family Manager - Main class
 */
class FamilyManager {
public:
    static FamilyManager& getInstance();

    // ============================================
    // RELATIONSHIP STATUS
    // ============================================

    /**
     * Set relationship status
     */
    bool setRelationshipStatus(
        const std::string& user_id,
        RelationshipStatus status,
        const std::string& partner_user_id = "");

    /**
     * Get relationship status
     */
    RelationshipStatus getRelationshipStatus(const std::string& user_id);

    /**
     * Get relationship status text
     */
    static std::string getRelationshipStatusText(RelationshipStatus status);

    /**
     * Get relationship status emoji
     */
    static std::string getRelationshipStatusEmoji(RelationshipStatus status);

    // ============================================
    // PARTNER
    // ============================================

    /**
     * Set partner
     */
    bool setPartner(
        const std::string& user_id,
        const std::string& partner_user_id,
        const std::string& partner_name);

    /**
     * Remove partner
     */
    bool removePartner(const std::string& user_id);

    /**
     * Get partner info
     */
    std::string getPartner(const std::string& user_id);

    /**
     * Set partner visibility
     */
    bool setPartnerVisibility(
        const std::string& user_id,
        bool is_public);

    /**
     * Confirm relationship (both users must confirm)
     */
    bool confirmRelationship(
        const std::string& user_id,
        const std::string& partner_user_id);

    // ============================================
    // CHILDREN
    // ============================================

    /**
     * Set children status
     */
    bool setChildrenStatus(
        const std::string& user_id,
        ChildrenStatus status);

    /**
     * Add child
     */
    bool addChild(
        const std::string& parent_user_id,
        const std::string& child_user_id,
        const std::string& child_name);

    /**
     * Remove child
     */
    bool removeChild(
        const std::string& parent_user_id,
        const std::string& child_user_id);

    /**
     * Get children count
     */
    int getChildrenCount(const std::string& user_id);

    /**
     * Get children list
     */
    std::vector<std::string> getChildren(const std::string& user_id);

    // ============================================
    // FAMILY MEMBERS
    // ============================================

    /**
     * Add family member
     */
    bool addFamilyMember(
        const std::string& user_id,
        const std::string& member_user_id,
        FamilyRole role);

    /**
     * Remove family member
     */
    bool removeFamilyMember(
        const std::string& user_id,
        const std::string& member_user_id);

    /**
     * Get family members
     */
    std::map<std::string, FamilyRole> getFamilyMembers(const std::string& user_id);

    /**
     * Get family members by role
     */
    std::vector<std::string> getFamilyMembersByRole(
        const std::string& user_id,
        FamilyRole role);

    // ============================================
    // FAMILY TREE
    // ============================================

    /**
     * Build family tree
     */
    FamilyTreeNode buildFamilyTree(const std::string& user_id);

    /**
     * Get relationship between two users
     */
    std::string getRelationshipBetween(
        const std::string& user1_id,
        const std::string& user2_id);

    // ============================================
    // FAMILY EVENTS
    // ============================================

    /**
     * Create family event
     */
    FamilyEvent createFamilyEvent(
        const std::string& family_id,
        const std::string& title,
        FamilyEventType type,
        int64_t event_date);

    /**
     * Get family events
     */
    std::vector<FamilyEvent> getFamilyEvents(
        const std::string& family_id,
        int64_t from_date = 0,
        int64_t to_date = 0);

    /**
     * Invite to family event
     */
    bool inviteToEvent(
        const std::string& event_id,
        const std::string& user_id);

    /**
     * RSVP to event
     */
    bool rsvpToEvent(
        const std::string& event_id,
        const std::string& user_id,
        bool attending);

    // ============================================
    // ANNIVERSARY
    // ============================================

    /**
     * Set anniversary date
     */
    bool setAnniversaryDate(
        const std::string& user_id,
        int64_t anniversary_date);

    /**
     * Get days until anniversary
     */
    int getDaysUntilAnniversary(const std::string& user_id);

    /**
     * Get years together
     */
    int getYearsTogether(const std::string& user_id);

    // ============================================
    // PRIVACY
    // ============================================

    /**
     * Set family info privacy
     */
    bool setFamilyPrivacy(
        const std::string& user_id,
        bool show_relationship,
        bool show_children,
        bool show_family_members);

    /**
     * Get family info with privacy filter
     */
    FamilyInfo getFamilyInfoWithPrivacy(
        const std::string& user_id,
        const std::string& viewer_user_id);

    // ============================================
    // STATUS DISPLAY
    // ============================================

    /**
     * Get formatted status for display
     */
    std::string getFormattedStatus(const std::string& user_id);

    /**
     * Get status with emoji
     */
    std::string getStatusWithEmoji(const std::string& user_id);

    /**
     * Get anniversary badge
     */
    std::string getAnniversaryBadge(const std::string& user_id);

private:
    FamilyManager() = default;
    ~FamilyManager() = default;
    FamilyManager(const FamilyManager&) = delete;
    FamilyManager& operator=(const FamilyManager&) = delete;

    struct Impl;
    std::unique_ptr<Impl> impl_;

    std::map<std::string, FamilyInfo> family_infos;
    std::map<std::string, std::vector<FamilyEvent>> family_events;
};

} // namespace features
} // namespace liberty_reach
} // namespace td
