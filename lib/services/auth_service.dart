import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'rpc_cache.dart';
import 'turso_client.dart';

/// Authentication service communicating with the Myaarchive Cloudflare Worker API.
///
/// Password hashing, schema validation, and user credentials live strictly
/// server-side. The client receives a signed JWT upon sign-in/sign-up which is
/// persisted securely and used to authenticate subsequent database and asset requests.
class AuthService {
  final String _workerBaseUrl;
  final TursoClient turso;
  final FlutterSecureStorage _secureStorage;
  late final Dio _dio;

  static const String _userPrefKey = 'myaarchive_current_user';
  static const String _tokenPrefKey = 'myaarchive_session_token';

  AuthService({
    required String workerBaseUrl,
    required this.turso,
    FlutterSecureStorage? secureStorage,
  })  : _workerBaseUrl = workerBaseUrl.endsWith('/')
            ? workerBaseUrl.substring(0, workerBaseUrl.length - 1)
            : workerBaseUrl,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// No-op: the users schema is maintained server-side.
  Future<void> ensureSchema() async {}

  /// Sign up a new user account via Worker.
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

    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/auth/signup',
        data: {
          'username': cleanUsername,
          'password': password,
          if (securityQuestion != null && securityQuestion.trim().isNotEmpty)
            'securityQuestion': securityQuestion.trim(),
          if (securityAnswer != null && securityAnswer.trim().isNotEmpty)
            'securityAnswer': securityAnswer.trim(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String? ?? '';

      turso.setSessionToken(token);
      await saveSessionUser(user, token: token);
      return user;
    } on DioException catch (e) {
      final msg = _errorMessage(e, 'Sign up failed');
      throw AuthException(msg);
    }
  }

  /// Sign in with username and password via Worker.
  Future<User> signIn({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanUsername = username.trim();

    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/auth/signin',
        data: {
          'username': cleanUsername,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String? ?? '';

      turso.setSessionToken(token);

      if (rememberMe) {
        await saveSessionUser(user, token: token);
      } else {
        await _clearPersistedSession();
      }
      return user;
    } on DioException catch (e) {
      final msg = _errorMessage(e, 'Invalid username or password');
      throw AuthException(msg);
    }
  }

  /// Get the currently signed-in user and session token from secure storage.
  Future<User?> getSessionUser() async {
    String? raw = await _secureStorage.read(key: _userPrefKey);

    // Migration from legacy SharedPreferences if needed
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
      final user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final token = await _secureStorage.read(key: _tokenPrefKey);
      if (token != null && token.isNotEmpty) {
        turso.setSessionToken(token);
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Save signed-in user session to secure storage.
  Future<void> saveSessionUser(User user, {String? token}) async {
    await _secureStorage.write(
      key: _userPrefKey,
      value: jsonEncode(user.toJson()),
    );
    if (token != null && token.isNotEmpty) {
      await _secureStorage.write(
        key: _tokenPrefKey,
        value: token,
      );
    }
  }

  /// Sign out and clear the local session.
  Future<void> signOut() async {
    turso.setSessionToken('');
    await RpcCache.clear();
    await _clearPersistedSession();
  }

  Future<void> _clearPersistedSession() async {
    await _secureStorage.delete(key: _userPrefKey);
    await _secureStorage.delete(key: _tokenPrefKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefKey);
    await prefs.remove(_tokenPrefKey);
  }

  /// Verify whether a user session is still valid.
  Future<bool> userExists(String userId) async {
    try {
      final response = await _dio.get(
        '$_workerBaseUrl/api/auth/me',
        options: Options(
          headers: {
            if (turso.sessionToken.isNotEmpty)
              'Authorization': 'Bearer ${turso.sessionToken}',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Verify current password for re-auth checkpoints.
  Future<bool> verifyPassword(String userId, String password) async {
    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/auth/verify-password',
        data: {'password': password},
        options: Options(
          headers: {
            if (turso.sessionToken.isNotEmpty)
              'Authorization': 'Bearer ${turso.sessionToken}',
          },
        ),
      );
      return response.data?['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Change password for current user.
  Future<void> changePassword(
      String userId, String currentPassword, String newPassword) async {
    if (newPassword.length < 4) {
      throw const AuthException('New password must be at least 4 characters');
    }
    try {
      await _dio.post(
        '$_workerBaseUrl/api/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(
          headers: {
            if (turso.sessionToken.isNotEmpty)
              'Authorization': 'Bearer ${turso.sessionToken}',
          },
        ),
      );
    } on DioException catch (e) {
      final msg = _errorMessage(e, 'Failed to change password');
      throw AuthException(msg);
    }
  }

  // ─── Password Recovery (Forgot Password) ───────────────────────────

  /// Returns the security question for [username], or null if the account
  /// doesn't exist or never set one up.
  Future<String?> getSecurityQuestion(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return null;

    try {
      final response = await _dio.get(
        '$_workerBaseUrl/api/auth/security-question',
        queryParameters: {'username': cleanUsername},
      );
      return response.data?['securityQuestion']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Resets the password for [username] using their security answer.
  Future<void> resetPasswordWithSecurityAnswer({
    required String username,
    required String securityAnswer,
    required String newPassword,
  }) async {
    if (newPassword.length < 4) {
      throw const AuthException('New password must be at least 4 characters');
    }

    try {
      await _dio.post(
        '$_workerBaseUrl/api/auth/reset-password',
        data: {
          'username': username.trim(),
          'securityAnswer': securityAnswer.trim(),
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      final msg = _errorMessage(e, 'Failed to reset password');
      throw AuthException(msg);
    }
  }

  // ─── Account Deletion ───────────────────────────────────────────────

  /// Permanently deletes the signed-in user's account and all associated data.
  ///
  /// The Worker verifies the password first, and if correct, cascades deletion
  /// through all user data, removes R2 files, and drops the user record atomically.
  Future<void> deleteAccount(String userId, String password) async {
    try {
      await _dio.post(
        '$_workerBaseUrl/api/auth/delete-account',
        data: {'password': password},
        options: Options(
          headers: {
            if (turso.sessionToken.isNotEmpty)
              'Authorization': 'Bearer ${turso.sessionToken}',
          },
        ),
      );
      await signOut();
    } on DioException catch (e) {
      final msg = _errorMessage(e, 'Failed to delete account');
      throw AuthException(msg);
    }
  }

  /// Turns a failed request into a message the user can act on. Prefers the
  /// server's own `error` text; when there was no response at all (offline,
  /// wrong Worker URL, blocked by CORS) says so and names the host, instead of
  /// surfacing Dio's raw XMLHttpRequest text.
  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (e.response == null) {
      final host = Uri.tryParse(_workerBaseUrl)?.host ?? _workerBaseUrl;
      return "Can't reach the server ($host). Check your connection and that "
          'the Worker is deployed at this address.';
    }
    return fallback;
  }

  void dispose() {
    _dio.close();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}