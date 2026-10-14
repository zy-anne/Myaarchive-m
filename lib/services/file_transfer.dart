import 'file_transfer_io.dart'
    if (dart.library.js_interop) 'file_transfer_web.dart' as impl;

/// Hands a text file to the user: the share sheet on mobile, a browser
/// download on web.
Future<void> saveTextFile(
  String filename,
  String content, {
  String mimeType = 'application/json',
}) =>
    impl.saveTextFile(filename, content, mimeType);
