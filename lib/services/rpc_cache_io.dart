import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> _dir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}/rpc_cache');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<File> _file(String key) async {
  final dir = await _dir();
  return File('${dir.path}/${sha1.convert(utf8.encode(key))}');
}

Future<String?> read(String key) async {
  try {
    final f = await _file(key);
    return await f.exists() ? await f.readAsString() : null;
  } catch (_) {
    return null;
  }
}

Future<void> write(String key, String value) async {
  try {
    await (await _file(key)).writeAsString(value, flush: true);
  } catch (_) {}
}

Future<void> clear() async {
  try {
    final dir = await _dir();
    await for (final entry in dir.list()) {
      if (entry is File) await entry.delete();
    }
  } catch (_) {}
}
