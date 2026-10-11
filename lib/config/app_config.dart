/// Application configuration for Myaarchive.
///
/// All database credentials and R2 signing keys are now server-side on the
/// Cloudflare Worker. The mobile app only needs the Worker base URL and
/// communicates via JWT-authenticated REST endpoints.
class AppConfig {
  AppConfig._();

  /// Base URL for the Myaarchive Cloudflare Worker API.
  ///
  /// Local development: 'http://10.0.2.2:8787' (Android emulator)
  ///                     'http://localhost:8787' (iOS simulator / web)
  /// Production: 'https://myaarchive-api.`<your-subdomain>`.workers.dev'
  static const String workerBaseUrl = 'https://myaarchive-api.maomao.workers.dev';
}
