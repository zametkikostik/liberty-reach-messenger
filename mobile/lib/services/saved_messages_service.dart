import 'dart:async';
import '../models/models.dart';

/// ⭐ Saved Messages Service
class SavedMessagesService {
  static SavedMessagesService? _instance;
  static SavedMessagesService get instance {
    _instance ??= SavedMessagesService._();
    return _instance!;
  }

  SavedMessagesService._();

  final List<SavedMessage> _savedMessages = [];

  Future<bool> saveMessage({
    required Message message,
    required String userId,
  }) async {
    if (_savedMessages.any((m) => m.message.id == message.id)) {
      return false;
    }

    _savedMessages.add(SavedMessage(
      message: message,
      savedAt: DateTime.now(),
      savedBy: userId,
    ));

    return true;
  }

  bool removeMessage(String messageId) {
    final initialLength = _savedMessages.length;
    _savedMessages.removeWhere((m) => m.message.id == messageId);
    return _savedMessages.length < initialLength;
  }

  List<SavedMessage> getSavedMessages() {
    return List.unmodifiable(_savedMessages);
  }

  bool isSaved(String messageId) {
    return _savedMessages.any((m) => m.message.id == messageId);
  }

  void wipe() {
    _savedMessages.clear();
  }
}

/// 💾 Сохранённое сообщение
class SavedMessage {
  final Message message;
  final DateTime savedAt;
  final String savedBy;

  const SavedMessage({
    required this.message,
    required this.savedAt,
    required this.savedBy,
  });
}
