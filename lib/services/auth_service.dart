import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'turso_client.dart';

/// Authentication service mirroring `auth/localAuth.js` from the Electron app.
///
/// Uses bcrypt hashing and Turso database storage, with local session persistence
/// via SharedPreferences.
class AuthService {
  final TursoClient _turso;
  static const String _userPrefKey = 'myaarchive_current_user';

  AuthService(this._turso);

  /// Ensure the users table exists with all required columns.
  Future<void> ensureSchema() async {
    await _turso.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    try {
      final info = await _turso.execute('PRAGMA table_info(users)');
      final existingCols = info.rows.map((r) => r['name']?.toString()).toSet();
      if (!existingCols.contains('security_question')) {
        await _turso.execute('ALTER TABLE users ADD COLUMN security_question TEXT');
      }
      if (!existingCols.contains('security_answer_hash')) {
        await _turso.execute('ALTER TABLE users ADD COLUMN security_answer_hash TEXT');
      }
    } catch (_) {}
  }

  /// Sign up a new user account.
  Future<User> signUp({
    required String username,
    required String password,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.length < 3) {
      throw const AuthException('Username must be at least 3 characters');
    }
    if (password.length < 4) {
      throw const AuthException('Password must be at least 4 characters');
    }

    await ensureSchema();

    final existing = await _turso.execute(
      'SELECT id FROM users WHERE username = ?',
      [cleanUsername],
    );
    if (existing.rows.isNotEmpty) {
      throw const AuthException('That username is already taken');
    }

    final id = const Uuid().v4();
    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    String? questionText;
    String? answerHash;
    final trimmedQuestion = securityQuestion?.trim();
    final trimmedAnswer = securityAnswer?.trim();
    if (trimmedQuestion != null &&
        trimmedQuestion.isNotEmpty &&
        trimmedAnswer != null &&
        trimmedAnswer.isNotEmpty) {
      questionText = trimmedQuestion;
      answerHash = BCrypt.hashpw(trimmedAnswer.toLowerCase(), BCrypt.gensalt());
    }

    await _turso.execute(
      'INSERT INTO users (id, username, password_hash, security_question, security_answer_hash) VALUES (?, ?, ?, ?, ?)',
      [id, cleanUsername, passwordHash, questionText, answerHash],
    );

    final user = User(
      id: id,
      username: cleanUsername,
      securityQuestion: questionText,
      createdAt: DateTime.now().toIso8601String(),
    );

    await saveSessionUser(user);
    return user;
  }

  /// Sign in with username and password.
  Future<User> signIn({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    await ensureSchema();

    final result = await _turso.execute(
      'SELECT * FROM users WHERE username = ?',
      [cleanUsername],
    );

    if (result.rows.isEmpty) {
      throw const AuthException('Invalid username or password');
    }

    final row = result.rows.first;
    final storedHash = row['password_hash']?.toString() ?? '';

    final isMatch = BCrypt.checkpw(password, storedHash);
    if (!isMatch) {
      throw const AuthException('Invalid username or password');
    }

    final user = User.fromJson(row);
    await saveSessionUser(user);
    return user;
  }

  /// Get the currently signed-in user from SharedPreferences.
  Future<User?> getSessionUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userPrefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Save signed-in user session locally.
  Future<void> saveSessionUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefKey, jsonEncode(user.toJson()));
  }

  /// Sign out and clear local session.
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefKey);
  }

  /// Verify whether a user id still exists on the database.
  Future<bool> userExists(String userId) async {
    final result = await _turso.execute(
      'SELECT id FROM users WHERE id = ?',
      [userId],
    );
    return result.rows.isNotEmpty;
  }

  /// Verify current password for re-auth checkpoints.
  Future<bool> verifyPassword(String userId, String password) async {
    final result = await _turso.execute(
      'SELECT password_hash FROM users WHERE id = ?',
      [userId],
    );
    if (result.rows.isEmpty) return false;
    final storedHash = result.rows.first['password_hash']?.toString() ?? '';
    return BCrypt.checkpw(password, storedHash);
  }

  /// Change password for current user.
  Future<void> changePassword(
      String userId, String currentPassword, String newPassword) async {
    if (newPassword.length < 4) {
      throw const AuthException('New password must be at least 4 characters');
    }
    final ok = await verifyPassword(userId, currentPassword);
    if (!ok) {
      throw const AuthException('Current password is incorrect');
    }
    final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await _turso.execute(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [newHash, userId],
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
