// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

void downloadCsvBytes(List<int> bytes, String filename) {
  final uint8List = Uint8List.fromList(bytes);
  final blob = html.Blob([uint8List], 'text/csv; charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Delay revoke so the browser has time to initiate the download
  Future.delayed(const Duration(milliseconds: 200), () {
    html.Url.revokeObjectUrl(url);
  });
}
