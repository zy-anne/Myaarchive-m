import 'rpc_cache_io.dart'
    if (dart.library.js_interop) 'rpc_cache_web.dart' as impl;

/// On-device copy of the last successful read responses, used to show your
/// library when the Worker can't be reached. Files on mobile, browser
/// storage on web. Best effort: every method swallows storage errors.
class RpcCache {
  static Future<String?> read(String key) => impl.read(key);
  static Future<void> write(String key, String value) => impl.write(key, value);
  static Future<void> clear() => impl.clear();
}
