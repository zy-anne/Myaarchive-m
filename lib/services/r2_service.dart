/// Cloudflare R2 asset storage service.
///
/// Mirrors `storage/r2.js` from the Electron app. Uses S3-compatible
/// presigned-URL downloads (the R2 bucket is private, same as the
/// desktop app). For uploads from mobile, the image bytes are PUT
/// directly to the R2 endpoint using AWS Signature V4.
library;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class R2Service {
  final String accountId;
  final String accessKeyId;
  final String secretAccessKey;
  final String bucketName;
  late final String _endpoint;
  late final Dio _dio;
  static const _uuid = Uuid();

  R2Service({
    required this.accountId,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucketName,
  }) {
    _endpoint = 'https://$accountId.r2.cloudflarestorage.com';
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  /// Generate a storage key. Matches `makeKey()` in r2.js.
  String makeKey(String prefix, [String originalFileName = '']) {
    String ext = '';
    final dotIdx = originalFileName.lastIndexOf('.');
    if (dotIdx >= 0) ext = originalFileName.substring(dotIdx);
    return '$prefix/${_uuid.v4()}$ext';
  }

  /// Download an asset from R2 into memory.
  Future<Uint8List?> downloadBytes(String key) async {
    if (key.isEmpty) return null;
    try {
      final url = '$_endpoint/$bucketName/$key';
      final now = DateTime.now().toUtc();
      final headers = _signRequest('GET', key, now, null);

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
      );
      return Uint8List.fromList(response.data ?? []);
    } catch (e) {
      return null;
    }
  }

  /// Get a presigned download URL for an R2 object (valid for [expiresIn] seconds).
  String getPresignedUrl(String key, {int expiresIn = 3600}) {
    if (key.isEmpty) return '';
    final now = DateTime.now().toUtc();
    final dateStamp = _dateStamp(now);
    final amzDate = _amzDate(now);
    final region = 'auto';
    final service = 's3';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final credential = '$accessKeyId/$credentialScope';

    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresIn.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedKeys = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(queryParams[k]!)}')
        .join('&');

    final host = '$accountId.r2.cloudflarestorage.com';
    final canonicalRequest = [
      'GET',
      '/$bucketName/${Uri.encodeFull(key)}',
      canonicalQueryString,
      'host:$host',
      '',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    return '$_endpoint/$bucketName/${Uri.encodeFull(key)}?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  /// Async helper for getting download URL.
  Future<String> getDownloadUrl(String key, {int expiresIn = 3600}) async {
    return getPresignedUrl(key, expiresIn: expiresIn);
  }

  /// Upload bytes to R2.
  Future<String> uploadBytes({
    required String key,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final url = '$_endpoint/$bucketName/$key';
    final now = DateTime.now().toUtc();
    final payloadHash = sha256.convert(bytes).toString();
    final headers = _signRequest('PUT', key, now, payloadHash, contentType: contentType);

    await _dio.put(
      url,
      data: bytes,
      options: Options(headers: headers),
    );
    return key;
  }

  /// Delete an object from R2.
  Future<void> deleteObject(String key) async {
    if (key.isEmpty) return;
    try {
      final url = '$_endpoint/$bucketName/$key';
      final now = DateTime.now().toUtc();
      final headers = _signRequest('DELETE', key, now, null);
      await _dio.delete(url, options: Options(headers: headers));
    } catch (_) {
      // Non-fatal — same behavior as r2.js
    }
  }

  // ─── AWS Signature V4 signing ────────────────────────────────────────

  Map<String, String> _signRequest(
    String method,
    String key,
    DateTime now,
    String? payloadHash, {
    String? contentType,
  }) {
    final dateStamp = _dateStamp(now);
    final amzDate = _amzDate(now);
    final host = '$accountId.r2.cloudflarestorage.com';
    final region = 'auto';
    final service = 's3';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    payloadHash ??= sha256.convert(utf8.encode('')).toString();

    final signedHeaders = contentType != null
        ? 'content-type;host;x-amz-content-sha256;x-amz-date'
        : 'host;x-amz-content-sha256;x-amz-date';

    final canonicalHeaderLines = contentType != null
        ? 'content-type:$contentType\nhost:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate'
        : 'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate';

    final canonicalRequest = [
      method,
      '/$bucketName/${Uri.encodeFull(key)}',
      '', // query string
      canonicalHeaderLines,
      '',
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    final headers = <String, String>{
      'Host': host,
      'X-Amz-Date': amzDate,
      'X-Amz-Content-SHA256': payloadHash,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature',
    };
    if (contentType != null) headers['Content-Type'] = contentType;
    return headers;
  }

  List<int> _getSignatureKey(String key, String dateStamp, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  String _dateStamp(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _amzDate(DateTime dt) =>
      '${_dateStamp(dt)}T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';

  void dispose() {
    _dio.close();
  }
}
