import 'dart:async';
import '../models/models.dart';

/// 👥 Group Chat Service
///
/// Управление групповыми чатами и каналами:
/// - Создание/удаление групп
/// - Добавление/удаление участников
/// - Роли (admin, moderator, member)
/// - Права доступа
class GroupChatService {
  static GroupChatService? _instance;
  static GroupChatService get instance {
    _instance ??= GroupChatService._();
    return _instance!;
  }

  GroupChatService._();

  /// Список участников группы
  final Map<String, List<GroupMember>> _groupMembers = {};

  /// Роли участников
  final Map<String, Map<String, MemberRole>> _memberRoles = {};

  /// Создание группы
  Future<Chat> createGroup({
    required String title,
    String? description,
    String? avatarUrl,
    required String creatorId,
    List<String>? memberIds,
  }) async {
    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Добавляем создателя как админа
    final members = <GroupMember>[
      GroupMember(
        id: creatorId,
        joinedAt: DateTime.now(),
        role: MemberRole.admin,
      ),
    ];

    // Добавляем остальных участников
    if (memberIds != null) {
      for (final memberId in memberIds) {
        if (memberId != creatorId) {
          members.add(GroupMember(
            id: memberId,
            joinedAt: DateTime.now(),
            role: MemberRole.member,
          ));
        }
      }
    }

    _groupMembers[groupId] = members;

    return Chat(
      id: groupId,
      type: ChatType.group,
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      memberCount: members.length,
    );
  }

  /// Создание канала
  Future<Chat> createChannel({
    required String title,
    String? description,
    String? avatarUrl,
    required String creatorId,
  }) async {
    final channelId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // В канале только админ (создатель)
    final members = <GroupMember>[
      GroupMember(
        id: creatorId,
        joinedAt: DateTime.now(),
        role: MemberRole.admin,
      ),
    ];

    _groupMembers[channelId] = members;

    return Chat(
      id: channelId,
      type: ChatType.channel,
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      memberCount: 0, // Подписчики не считаются как участники
    );
  }

  /// Добавление участника в группу
  Future<bool> addMember({
    required String groupId,
    required String memberId,
    MemberRole role = MemberRole.member,
  }) async {
    if (!_groupMembers.containsKey(groupId)) return false;

    _groupMembers[groupId]!.add(GroupMember(
      id: memberId,
      joinedAt: DateTime.now(),
      role: role,
    ));

    return true;
  }

  /// Удаление участника из группы
  Future<bool> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    if (!_groupMembers.containsKey(groupId)) return false;

    _groupMembers[groupId]!.removeWhere((m) => m.id == memberId);
    return true;
  }

  /// Получение участников группы
  List<GroupMember> getMembers(String groupId) {
    return _groupMembers[groupId] ?? [];
  }

  /// Проверка прав участника
  MemberRole? getMemberRole(String groupId, String memberId) {
    final members = _groupMembers[groupId];
    if (members == null) return null;

    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => GroupMember(
        id: '',
        joinedAt: DateTime.now(),
        role: MemberRole.none,
      ),
    );

    return member.role == MemberRole.none ? null : member.role;
  }

  /// Проверка: является ли пользователь админом
  bool isAdmin(String groupId, String userId) {
    final role = getMemberRole(groupId, userId);
    return role == MemberRole.admin || role == MemberRole.moderator;
  }

  /// Очистка всех данных
  void wipe() {
    _groupMembers.clear();
    _memberRoles.clear();
  }
}

/// 👤 Участник группы
class GroupMember {
  final String id;
  final DateTime joinedAt;
  final MemberRole role;

  const GroupMember({
    required this.id,
    required this.joinedAt,
    required this.role,
  });
}

/// 🎭 Роли участников
enum MemberRole {
  none,      // Нет роли
  member,    // Обычный участник
  moderator, // Модератор
  admin,     // Администратор
  owner,     // Владелец
}
