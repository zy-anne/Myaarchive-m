import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/app_providers.dart';

/// Outcome of [ImageUploader.pickAndUpload]. [keys] are the storage keys of
/// the pictures that did upload, in the order they were picked; [error] is
/// set if one failed (later pictures are not attempted).
class ImageUploadResult {
  final List<String> keys;
  final Object? error;
  final int picked;

  const ImageUploadResult({
    required this.keys,
    required this.picked,
    this.error,
  });

  /// The user closed the picker without choosing anything.
  bool get cancelled => picked == 0;
}

/// Picks pictures from the device and uploads them to cloud storage through
/// the Worker, which scopes them under the signed-in user's own folder.
class ImageUploader {
  static final ImagePicker _picker = ImagePicker();

  static String _contentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// [prefix] is the storage folder: `gallery`, `characters`, `covers`...
  static Future<ImageUploadResult> pickAndUpload(
    WidgetRef ref, {
    required String prefix,
    bool multiple = false,
    double maxWidth = 1600,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<XFile> files;
    if (multiple) {
      files = await _picker.pickMultiImage(maxWidth: maxWidth, imageQuality: 85);
    } else {
      final one = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        imageQuality: 85,
      );
      files = one == null ? <XFile>[] : <XFile>[one];
    }
    if (files.isEmpty) return const ImageUploadResult(keys: [], picked: 0);

    final r2 = ref.read(r2ServiceProvider);
    final keys = <String>[];
    onProgress?.call(0, files.length);
    for (final file in files) {
      try {
        final key = await r2.uploadBytes(
          key: r2.makeKey(prefix, file.name),
          bytes: await file.readAsBytes(),
          contentType: _contentType(file.name),
          prefix: prefix,
        );
        keys.add(key);
        onProgress?.call(keys.length, files.length);
      } catch (e) {
        return ImageUploadResult(keys: keys, picked: files.length, error: e);
      }
    }
    return ImageUploadResult(keys: keys, picked: files.length);
  }
}
