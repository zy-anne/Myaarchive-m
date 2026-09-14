/// Application configuration and remote credentials for Myaarchive.
///
/// Pre-configured with the default Turso database and Cloudflare R2 bucket
/// matching the Electron desktop app, with support for local overrides.
class AppConfig {
  AppConfig._();

  // Turso Database configuration
  static const String defaultTursoDatabaseUrl =
      'libsql://myaarchive-maomao.aws-ap-northeast-1.turso.io';
  static const String defaultTursoAuthToken =
      'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3ODUyNDQ5MjUsImlkIjoiMDE5ZmE4OGMtMTUwMS03N2JmLTg2ZjgtZTUwNjllMThlY2RlIiwia2lkIjoiNnI2VzBnSXFWV0tMT01Eemx2NU03ZmFMT2lDcm4taE9hVklHNllrLUpHWSIsInJpZCI6ImU5NGE1M2FkLTMwZTYtNDMxOC1hMThjLTVlZDRjNTA2MGE1NSJ9.l6rAVl796bBHGDmHq9aUxgfZ6hOKJs18qxk9LebTXq5LQVlwJRjdNrAurjcwV2G_SfkveZ7CcbITsLyEA-WHCg';

  // Cloudflare R2 Configuration
  static const String defaultR2AccountId = '3cca4f870c05036add3c532ebf545425';
  static const String defaultR2AccessKeyId = 'b2beb118af1e3e64a4b55dc94f5f1a56';
  static const String defaultR2SecretAccessKey =
      '3e69a106e990641654a0f7d06a4e814b5d0a49999172c6104c20a86fbaa0f51c';
  static const String defaultR2BucketName = 'myaarchive-assets';
}
