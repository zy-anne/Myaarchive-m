/// API client for the Myaarchive Cloudflare Worker.
///
/// The app never talks to the database directly and holds no database
/// credentials. Every data call goes to an owner-checked `/api/rpc/<op>`
/// endpoint authenticated by the user's session token.
library;
import 'package:dio/dio.dart';

/// Lightweight HTTP client for the Worker's data API.
class TursoClient {
  final String _workerBaseUrl;
  String sessionToken;
  late final Dio _dio;

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
  }

  /// Update the session token (called after sign-in / sign-up).
  void setSessionToken(String token) {
    sessionToken = token;
  }

  /// Calls an owner-checked Worker operation (`POST /api/rpc/<op>`).
  ///
  /// The Worker identifies the user from the session token and verifies
  /// ownership of every row itself, so callers never send a user id or SQL.
  Future<Map<String, dynamic>> rpc(String op, [Map<String, dynamic>? args]) async {
    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/rpc/$op',
        data: args ?? <String, dynamic>{},
        options: Options(
          headers: {
            if (sessionToken.isNotEmpty) 'Authorization': 'Bearer $sessionToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?.toString())
          : null;
      throw TursoException(msg ?? e.message ?? 'Request failed');
    }
  }

  void dispose() {
    _dio.close();
  }
}

class TursoException implements Exception {
  final String message;
  const TursoException(this.message);

  @override
  String toString() => 'TursoException: $message';
}
