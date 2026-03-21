import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// 🔐 Auth Service - Регистрация и аутентификация
///
/// - username: только латиница [a-zA-Z0-9_]
/// - fullName: ФИО для отображения
/// - password: хешируется локально
class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  AuthService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Регулярка для username (только латиница)
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  /// Проверка username
  static bool isValidUsername(String username) {
    return _usernameRegex.hasMatch(username);
  }

  /// Регистрация пользователя
  Future<bool> register({
    required String username,
    required String fullName,
    required String password,
  }) async {
    if (!isValidUsername(username)) {
      throw Exception('Username must be 3-20 chars (a-zA-Z0-9_)');
    }

    if (fullName.trim().isEmpty) {
      throw Exception('Full Name is required');
    }

    // Хешируем пароль
    final passwordHash = sha256.convert(utf8.encode(password)).toString();

    // Сохраняем данные
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'fullName', value: fullName);
    await _storage.write(key: 'passwordHash', value: passwordHash);
    await _storage.write(key: 'isLoggedIn', value: 'true');

    return true;
  }

  /// Вход
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final storedUsername = await _storage.read(key: 'username');
    final passwordHash = await _storage.read(key: 'passwordHash');

    if (storedUsername != username) {
      return false;
    }

    final inputHash = sha256.convert(utf8.encode(password)).toString();
    if (inputHash != passwordHash) {
      return false;
    }

    await _storage.write(key: 'isLoggedIn', value: 'true');
    return true;
  }

  /// Выход
  Future<void> logout() async {
    await _storage.write(key: 'isLoggedIn', value: 'false');
  }

  /// Проверка: залогинен ли пользователь
  Future<bool> isLoggedIn() async {
    final loggedIn = await _storage.read(key: 'isLoggedIn');
    return loggedIn == 'true';
  }

  /// Получить текущее имя
  Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  /// Получить полное имя
  Future<String?> getFullName() async {
    return await _storage.read(key: 'fullName');
  }
}
