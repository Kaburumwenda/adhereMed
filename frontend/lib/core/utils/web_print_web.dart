// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void openPrintWindow(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  html.Url.revokeObjectUrl(url);
}
