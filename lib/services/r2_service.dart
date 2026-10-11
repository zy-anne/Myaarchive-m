/// Cloudflare R2 asset storage service — proxied through the Myaarchive Worker.
///
/// All asset uploads, signed download URLs, and deletions are routed through
/// the Cloudflare Worker API (`/api/assets/*`). No R2 access keys or S3
/// credentials ever touch the mobile client.
library;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  const _CachedUrl({required this.url, required this.expiresAt});

  bool get isValid =>
      DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 5)));
}

class R2Service {
  final String _workerBaseUrl;
  final String Function()? tokenProvider;
  late final Dio _dio;
  static const _uuid = Uuid();

  final Map<String, _CachedUrl> _urlCache = {};

  R2Service({
    required String workerBaseUrl,
    this.tokenProvider,
  })  : _workerBaseUrl = workerBaseUrl.endsWith('/')
            ? workerBaseUrl.substring(0, workerBaseUrl.length - 1)
            : workerBaseUrl {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  String get _token => tokenProvider?.call() ?? '';

  /// Client-side key suggestion for backward compatibility.
  /// Note: The Worker automatically scopes uploaded files under `u/<userId>/<prefix>/`.
  String makeKey(String prefix, [String originalFileName = '']) {
    String ext = '';
    final dotIdx = originalFileName.lastIndexOf('.');
    if (dotIdx >= 0) ext = originalFileName.substring(dotIdx);
    return '$prefix/${_uuid.v4()}$ext';
  }

  /// Get a signed download URL for an asset key.
  ///
  /// Caches the generated signed link in-memory until shortly before expiration
  /// to minimize unnecessary network round-trips.
  Future<String> getDownloadUrl(String key, {int expiresIn = 3600}) async {
    if (key.isEmpty) return '';

    final cached = _urlCache[key];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      final response = await _dio.get(
        '$_workerBaseUrl/api/assets/presign-download',
        queryParameters: {
          'key': key,
          'expiresIn': expiresIn,
        },
        options: Options(
          headers: {
            if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
        ),
      );

      final data = response.data;
      if (data is Map) {
        final relativeUrl = data['downloadUrl'] as String?;
        final expTimestamp = data['expiresAt'] as int?;

        if (relativeUrl != null) {
          final fullUrl = relativeUrl.startsWith('http')
              ? relativeUrl
              : '$_workerBaseUrl$relativeUrl';

          final expiresAt = expTimestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000)
              : DateTime.now().add(Duration(seconds: expiresIn));

          _urlCache[key] = _CachedUrl(url: fullUrl, expiresAt: expiresAt);
          return fullUrl;
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Synchronous fallback helper for callers expecting getPresignedUrl.
  String getPresignedUrl(String key, {int expiresIn = 3600}) {
    final cached = _urlCache[key];
    if (cached != null && cached.isValid) {
      return cached.url;
    }
    return '';
  }

  /// Download asset bytes from R2 via Worker.
  Future<Uint8List?> downloadBytes(String key) async {
    if (key.isEmpty) return null;
    try {
      final url = await getDownloadUrl(key);
      if (url.isEmpty) return null;

      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? []);
    } catch (_) {
      return null;
    }
  }

  /// Upload image bytes to R2 via the Worker.
  ///
  /// The Worker validates the content type, enforces file size limits,
  /// scopes the object under `u/<userId>/`, and returns the final storage key.
  Future<String> uploadBytes({
    String? key,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    String prefix = 'covers',
  }) async {
    // Infer prefix from key if provided (e.g., 'covers/abc.jpg' -> 'covers')
    var targetPrefix = prefix;
    if (key != null && key.contains('/')) {
      final parts = key.split('/');
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        targetPrefix = parts.first;
      }
    }

    final response = await _dio.post(
      '$_workerBaseUrl/api/assets/upload',
      queryParameters: {'prefix': targetPrefix},
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
        },
      ),
    );

    final data = response.data;
    if (data is Map && data['key'] != null) {
      return data['key'].toString();
    }
    throw Exception('Upload failed: invalid server response');
  }

  /// Delete an object from R2 through the Worker.
  Future<void> deleteObject(String key) async {
    if (key.isEmpty) return;
    try {
      _urlCache.remove(key);
      await _dio.delete(
        '$_workerBaseUrl/api/assets/${Uri.encodeComponent(key)}',
        options: Options(
          headers: {
            if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
        ),
      );
    } catch (_) {
      // Non-fatal
    }
  }

  void dispose() {
    _dio.close();
  }
}
