import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveTextFile(
    String filename, String content, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    subject: filename,
  );
}
