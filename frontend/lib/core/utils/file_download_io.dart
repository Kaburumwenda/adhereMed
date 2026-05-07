import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes the file to the Downloads directory (or Documents as fallback).
/// Returns the saved path.
Future<String?> downloadTextFile(String filename, String content) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  return file.path;
}
