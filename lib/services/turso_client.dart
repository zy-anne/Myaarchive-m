/// API client for the Myaarchive Cloudflare Worker.
///
/// The app never talks to the database directly and holds no database
/// credentials. Every data call goes to an owner-checked `/api/rpc/<op>`
/// endpoint authenticated by the user's session token.
library;
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'rpc_cache.dart';

/// Lightweight HTTP client for the Worker's data API.
class TursoClient {
  final String _workerBaseUrl;
  String sessionToken;
  late final Dio _dio;

  /// Signed-in user id, read from the session token. Scopes the on-device
  /// cache so one account never sees another's saved data.
  String _userId = '';

  /// True while the last read was answered from the on-device cache because
  /// the Worker couldn't be reached. The UI shows an "Offline" banner.
  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// Called once when the Worker rejects the session token (HTTP 401), e.g.
  /// it expired. The app uses this to sign out and return to the login screen.
  void Function()? onUnauthorized;

  TursoClient({
    required String workerBaseUrl,
    this.sessionToken = '',
  })  : _workerBaseUrl = workerBaseUrl.endsWith('/')
            ? workerBaseUrl.substring(0, workerBaseUrl.length - 1)
            : workerBaseUrl {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _userId = _subjectOf(sessionToken);
  }

  /// Update the session token (called after sign-in / sign-up).
  void setSessionToken(String token) {
    sessionToken = token;
    _userId = _subjectOf(token);
    if (token.isEmpty) offline.value = false;
  }

  static String _subjectOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map ? '${payload['sub'] ?? ''}' : '';
    } catch (_) {
      return '';
    }
  }

  /// The bootstrap response also answers three plain reads; save them under
  /// their own keys so those reads still work offline after a refresh.
  void _cacheBootstrapParts(Map<String, dynamic> result) {
    const parts = {
      'libraries': 'libraries.getAll',
      'statuses': 'statuses.getAll',
      'settings': 'settings.getAll',
    };
    parts.forEach((field, op) {
      final rows = result[field];
      if (rows is List) {
        unawaited(RpcCache.write(
          '$_userId|$op|{}',
          jsonEncode(<String, dynamic>{'rows': rows}),
        ));
      }
    });
  }

  /// Read-only operations whose answers are kept for offline use.
  static bool _cacheable(String op) =>
      op == 'app.bootstrap' ||
      op.endsWith('.getAll') ||
      op.endsWith('.getById') ||
      op.endsWith('.list');

  /// Calls an owner-checked Worker operation (`POST /api/rpc/<op>`).
  ///
  /// The Worker identifies the user from the session token and verifies
  /// ownership of every row itself, so callers never send a user id or SQL.
  Future<Map<String, dynamic>> rpc(String op,
      [Map<String, dynamic>? args, Duration? timeout]) async {
    final cacheKey = (_userId.isNotEmpty && _cacheable(op))
        ? '$_userId|$op|${jsonEncode(args ?? const <String, dynamic>{})}'
        : null;
    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/rpc/$op',
        data: args ?? <String, dynamic>{},
        options: Options(
          receiveTimeout: timeout,
          sendTimeout: timeout,
          headers: {
            if (sessionToken.isNotEmpty) 'Authorization': 'Bearer $sessionToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      final result =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      offline.value = false;
      if (cacheKey != null) {
        unawaited(RpcCache.write(cacheKey, jsonEncode(result)));
        if (op == 'app.bootstrap') _cacheBootstrapParts(result);
      }
      return result;
    } on DioException catch (e) {
      // No HTTP response at all means the Worker couldn't be reached.
      if (e.response == null && e.type != DioExceptionType.cancel) {
        if (cacheKey != null) {
          final saved = await RpcCache.read(cacheKey);
          if (saved != null) {
            try {
              final decoded = jsonDecode(saved);
              if (decoded is Map) {
                offline.value = true;
                return Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}
          }
          throw const TursoException(
              "Can't reach the server, and this hasn't been saved on this device yet.");
        }
        throw const TursoException(
            "Can't reach the server, so changes can't be saved right now.");
      }
      if (e.response?.statusCode == 401 && sessionToken.isNotEmpty) {
        // Clear first so a burst of failing requests only triggers one sign-out.
        setSessionToken('');
        onUnauthorized?.call();
        throw const TursoException('Your session has expired. Please sign in again.');
      }
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?.toString())
          : null;
      throw TursoException(msg ?? e.message ?? 'Request failed');
    }
  }

  void dispose() {
    offline.dispose();
    _dio.close();
  }
}

class TursoException implements Exception {
  final String message;
  const TursoException(this.message);

  @override
  String toString() => 'TursoException: $message';
}
