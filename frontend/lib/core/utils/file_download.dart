// Conditional export: web download vs desktop/mobile file write.
export 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart';
