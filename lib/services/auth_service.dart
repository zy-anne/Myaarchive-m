import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'turso_client.dart';

/// Authentication service mirroring `auth/localAuth.js` from the Electron app.
///
/// Uses bcrypt hashing and Turso database storage. The signed-in session is
/// persisted in [FlutterSecureStorage] (Keychain on iOS, EncryptedSharedPreferences
/// on Android) rather than plain SharedPreferences, since it holds the
/// user's id and username.
class AuthService {
  final TursoClient _turso;
  final FlutterSecureStorage _secureStorage;
  static const String _userPrefKey = 'myaarchive_current_user';

  AuthService(this._turso, {FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

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
  ///
  /// [rememberMe] (default true — "Keep me signed in") controls whether the
  /// session is written to secure storage for automatic sign-in on the
  /// next app launch. When false, the signed-in state still lives in
  /// memory for the rest of this run (via [AuthStateNotifier]'s state) but
  /// nothing is persisted, and any previously remembered session for this
  /// device is cleared — so closing and reopening the app requires signing
  /// in again.
  Future<User> signIn({
    required String username,
    required String password,
    bool rememberMe = true,
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
    if (rememberMe) {
      await saveSessionUser(user);
    } else {
      // Don't leave a stale persisted session behind for a device the
      // person explicitly chose not to be remembered on.
      await _secureStorage.delete(key: _userPrefKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userPrefKey);
    }
    return user;
  }

  /// Get the currently signed-in user from secure storage.
  ///
  /// If secure storage is empty but a legacy SharedPreferences session is
  /// found (from before the switch to secure storage), it's migrated over
  /// and the plaintext copy is removed — so upgrading the app doesn't sign
  /// anyone out.
  Future<User?> getSessionUser() async {
    String? raw = await _secureStorage.read(key: _userPrefKey);

    if (raw == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_userPrefKey);
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
        await _secureStorage.write(key: _userPrefKey, value: legacy);
        await prefs.remove(_userPrefKey);
      }
    }

    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Save signed-in user session to secure storage.
  Future<void> saveSessionUser(User user) async {
    await _secureStorage.write(
      key: _userPrefKey,
      value: jsonEncode(user.toJson()),
    );
  }

  /// Sign out and clear the local session (secure storage, plus any
  /// leftover legacy SharedPreferences copy).
  Future<void> signOut() async {
    await _secureStorage.delete(key: _userPrefKey);
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

  // ─── Password Recovery (Forgot Password) ───────────────────────────
  //
  // Uses the optional security question/answer captured at sign-up. If an
  // account has no recovery question set up, there's no self-serve way to
  // reset the password — the caller should surface that clearly rather
  // than silently failing.

  /// Returns the security question for [username], or null if the account
  /// doesn't exist or never set one up.
  Future<String?> getSecurityQuestion(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return null;
    await ensureSchema();

    final result = await _turso.execute(
      'SELECT security_question, security_answer_hash FROM users WHERE username = ?',
      [cleanUsername],
    );
    if (result.rows.isEmpty) return null;

    final row = result.rows.first;
    final question = row['security_question']?.toString();
    final answerHash = row['security_answer_hash']?.toString();
    if (question == null || question.isEmpty) return null;
    if (answerHash == null || answerHash.isEmpty) return null;
    return question;
  }

  /// Resets the password for [username] using their security answer.
  ///
  /// Throws [AuthException] if the username doesn't exist, never set up a
  /// recovery question, or the answer doesn't match.
  Future<void> resetPasswordWithSecurityAnswer({
    required String username,
    required String securityAnswer,
    required String newPassword,
  }) async {
    if (newPassword.length < 4) {
      throw const AuthException('New password must be at least 4 characters');
    }

    final cleanUsername = username.trim();
    final result = await _turso.execute(
      'SELECT id, security_answer_hash FROM users WHERE username = ?',
      [cleanUsername],
    );
    if (result.rows.isEmpty) {
      throw const AuthException('No account found with that username');
    }

    final row = result.rows.first;
    final answerHash = row['security_answer_hash']?.toString();
    if (answerHash == null || answerHash.isEmpty) {
      throw const AuthException('No recovery question set up for this account');
    }

    final isMatch =
        BCrypt.checkpw(securityAnswer.trim().toLowerCase(), answerHash);
    if (!isMatch) {
      throw const AuthException('That answer doesn\'t match our records');
    }

    final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await _turso.execute(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [newHash, row['id']],
    );
  }

  // ─── Account Deletion ───────────────────────────────────────────────

  /// Permanently deletes the signed-in user's account after verifying
  /// their password. Callers should first delete the user's owned data
  /// via `DataLayer.deleteAllDataForOwner` — this method only removes the
  /// `users` row and clears the local session.
  Future<void> deleteAccount(String userId, String password) async {
    final ok = await verifyPassword(userId, password);
    if (!ok) {
      throw const AuthException('Password is incorrect');
    }
    await _turso.execute('DELETE FROM users WHERE id = ?', [userId]);
    await signOut();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}