/// Cloudflare R2 asset storage service — proxied through the Myaarchive Worker.
///
/// All asset uploads, signed download URLs, and deletions are routed through
/// the Cloudflare Worker API (`/api/assets/*`). No R2 access keys or S3
/// credentials ever touch the mobile client.
library;
import 'dart:async';
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

  // Requests made within one short window are sent to the Worker together.
  final Map<String, Completer<String>> _pending = {};
  Timer? _flushTimer;
  int _batchExpiresIn = 3600;
  static const _batchWindow = Duration(milliseconds: 40);
  static const _maxBatch = 100;

  /// Get a signed download URL for an asset key.
  ///
  /// Caches the generated signed link in-memory until shortly before expiration
  /// to minimize unnecessary network round-trips. Lookups that happen close
  /// together (a grid of covers) share a single `/presign-batch` request.
  Future<String> getDownloadUrl(String key, {int expiresIn = 3600}) {
    if (key.isEmpty) return Future.value('');

    final cached = _urlCache[key];
    if (cached != null && cached.isValid) {
      return Future.value(cached.url);
    }

    final existing = _pending[key];
    if (existing != null) return existing.future;

    final completer = Completer<String>();
    _pending[key] = completer;
    _batchExpiresIn = expiresIn;
    if (_pending.length >= _maxBatch) {
      _flushTimer?.cancel();
      _flush();
    } else {
      _flushTimer ??= Timer(_batchWindow, _flush);
    }
    return completer.future;
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final batch = Map<String, Completer<String>>.from(_pending);
    _pending.clear();
    if (batch.isEmpty) return;
    final expiresIn = _batchExpiresIn;

    try {
      final response = await _dio.post(
        '$_workerBaseUrl/api/assets/presign-batch',
        data: {'keys': batch.keys.toList(), 'expiresIn': expiresIn},
        options: Options(
          headers: {
            if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      final urls = data is Map && data['urls'] is Map ? data['urls'] as Map : const {};
      batch.forEach((key, completer) {
        var result = '';
        final entry = urls[key];
        if (entry is Map && entry['downloadUrl'] is String) {
          final relativeUrl = entry['downloadUrl'] as String;
          result = relativeUrl.startsWith('http')
              ? relativeUrl
              : '$_workerBaseUrl$relativeUrl';
          final exp = entry['expiresAt'];
          _urlCache[key] = _CachedUrl(
            url: result,
            expiresAt: exp is int
                ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
                : DateTime.now().add(Duration(seconds: expiresIn)),
          );
        }
        completer.complete(result);
      });
    } catch (_) {
      for (final c in batch.values) {
        if (!c.isCompleted) c.complete('');
      }
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
    _flushTimer?.cancel();
    _dio.close();
  }
}
