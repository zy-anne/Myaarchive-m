# Myaarchive Mobile

Flutter companion app for Myaarchive, a personal catalog and reading tracker for books, manga, webtoons, light novels, and series.

## Features

- **Personal Catalog**: Track series, books, and standalone releases across custom libraries.
- **Reading Progress**: Manage volumes, reading status, chapter logs, and ratings.
- **Rich Metadata**: Authors, artists, publishers, original language, translation status, content warnings, and tags.
- **Cloud Sync**: Cloudflare R2 cover asset storage and Turso cloud database synchronization.
- **Themes & Palettes**: Light/dark mode with dynamic themed palettes (Indigo, Sakura, Forest, Saffron, Rose, Cyberpunk, etc.).

## Getting Started

1. Ensure Flutter 3.x+ is installed.
2. Run `flutter pub get` to fetch dependencies.
3. Launch the app with `flutter run`.
## Android release signing

1. Create a keystore once (keep it and its passwords somewhere safe; losing it means you can't update the app):
   `keytool -genkey -v -keystore ~/myaarchive-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias myaarchive`
2. Create `android/key.properties` (git-ignored) with:
   ```
   storeFile=/absolute/path/to/myaarchive-release.jks
   storePassword=...
   keyAlias=myaarchive
   keyPassword=...
   ```
3. Build with `flutter build appbundle --release` (or `apk`). Without `key.properties` the build falls back to debug signing and can't be published.
