import 'package:flutter/material.dart';
import '../models/models.dart';

/// 👨‍👩‍👧 Family Status Service
///
/// Управление семейными статусами пользователей
class FamilyStatusService {
  static FamilyStatusService? _instance;
  static FamilyStatusService get instance {
    _instance ??= FamilyStatusService._();
    return _instance!;
  }

  FamilyStatusService._();

  // Текущий статус пользователя
  FamilyStatus? _currentStatus;
  String? _partnerUserId;

  // Getters
  FamilyStatus? get currentStatus => _currentStatus;
  String? get partnerUserId => _partnerUserId;
  bool get isInRelationship => _currentStatus != null && _currentStatus != FamilyStatus.single;

  /// Установить семейный статус
  Future<bool> setFamilyStatus(FamilyStatus status, {String? partnerUserId}) async {
    _currentStatus = status;
    _partnerUserId = partnerUserId;
    
    print('👨‍👩‍👧 Family status set: $status');
    return true;
  }

  /// Запросить изменение статуса (требует подтверждения партнёра)
  Future<bool> requestRelationshipChange({
    required FamilyStatus newStatus,
    required String partnerUserId,
  }) async {
    // TODO: Отправить запрос партнёру через P2P
    print('💕 Request sent to $partnerUserId for $newStatus');
    return true;
  }

  /// Принять запрос от партнёра
  Future<bool> acceptRelationshipRequest({
    required FamilyStatus newStatus,
    required String fromUserId,
  }) async {
    _currentStatus = newStatus;
    _partnerUserId = fromUserId;
    
    print('💕 Relationship accepted: $newStatus with $fromUserId');
    return true;
  }

  /// Разорвать отношения
  Future<bool> breakRelationship() async {
    _currentStatus = FamilyStatus.single;
    _partnerUserId = null;
    
    print('💔 Relationship ended');
    return true;
  }

  /// Получить иконку статуса
  IconData getStatusIcon(FamilyStatus status) {
    switch (status) {
      case FamilyStatus.single:
        return Icons.person;
      case FamilyStatus.dating:
        return Icons.favorite;
      case FamilyStatus.engaged:
        return Icons.favorite_border;
      case FamilyStatus.married:
        return Icons.favorite_rounded;
      case FamilyStatus.inRelationship:
        return Icons.people;
    }
  }

  /// Получить текст статуса
  String getStatusText(FamilyStatus status) {
    switch (status) {
      case FamilyStatus.single:
        return 'Не женат/не замужем';
      case FamilyStatus.dating:
        return 'Влюблён/влюблена';
      case FamilyStatus.engaged:
        return 'Помолвлен/помолвлена';
      case FamilyStatus.married:
        return 'Женат/замужем';
      case FamilyStatus.inRelationship:
        return 'В активном поиске';
    }
  }

  /// Получить цвет статуса
  Color getStatusColor(FamilyStatus status) {
    switch (status) {
      case FamilyStatus.single:
        return Colors.grey;
      case FamilyStatus.dating:
        return Colors.red;
      case FamilyStatus.engaged:
        return Colors.pink;
      case FamilyStatus.married:
        return Colors.deepPurple;
      case FamilyStatus.inRelationship:
        return Colors.blue;
    }
  }

  /// Очистить данные
  void wipe() {
    _currentStatus = null;
    _partnerUserId = null;
  }
}
