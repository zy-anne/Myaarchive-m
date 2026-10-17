import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Outcome of [FileAttachmentUploader.pickAndUpload].
class FileAttachmentResult {
  final String key;
  final String fileName;
  final int fileSize;
  final Object? error;
  final bool cancelled;

  const FileAttachmentResult({
    this.key = '',
    this.fileName = '',
    this.fileSize = 0,
    this.error,
    this.cancelled = false,
  });

  bool get isSuccess => key.isNotEmpty && error == null;
}

/// Helper for picking and uploading book resources & attachments (PDF, EPUB, TXT, MD, images)
/// up to 10 MB to Cloudflare R2 via the Worker.
class FileAttachmentUploader {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const List<String> allowedExtensions = [
    'pdf',
    'epub',
    'txt',
    'md',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];

  static String getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.epub')) return 'application/epub+zip';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  static Future<FileAttachmentResult> pickAndUpload(WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return const FileAttachmentResult(cancelled: true);
    }

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return FileAttachmentResult(
        fileName: file.name,
        error: 'Could not read file data from device',
      );
    }

    if (bytes.length > maxFileSizeBytes) {
      return FileAttachmentResult(
        fileName: file.name,
        fileSize: bytes.length,
        error: 'File exceeds the 10 MB limit (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    }

    final mime = getMimeType(file.name);
    final r2 = ref.read(r2ServiceProvider);

    try {
      final key = await r2.uploadBytes(
        bytes: bytes,
        contentType: mime,
        prefix: 'attachments',
      );
      return FileAttachmentResult(
        key: key,
        fileName: file.name,
        fileSize: bytes.length,
      );
    } catch (e) {
      return FileAttachmentResult(
        fileName: file.name,
        fileSize: bytes.length,
        error: e,
      );
    }
  }
}
