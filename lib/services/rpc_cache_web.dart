import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'rpc_cache:';

Future<String?> read(String key) async {
  try {
    return (await SharedPreferences.getInstance()).getString('$_prefix$key');
  } catch (_) {
    return null;
  }
}

Future<void> write(String key, String value) async {
  try {
    await (await SharedPreferences.getInstance()).setString('$_prefix$key', value);
  } catch (_) {
    // Storage full or unavailable: caching is optional.
  }
}

Future<void> clear() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  } catch (_) {}
}
