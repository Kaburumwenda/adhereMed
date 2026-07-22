import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'hc_common.dart';

/// Supported document preview types.
enum _DocKind { image, pdf, office, text, other }

_DocKind _classify(String? fileType, String url) {
  final ext = (fileType?.isNotEmpty == true
          ? fileType!
          : (url.lastIndexOf('.') >= 0 ? url.substring(url.lastIndexOf('.') + 1) : ''))
      .toLowerCase();
  const images = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
  const office = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf'];
  const texts = ['txt', 'log', 'csv', 'md', 'json', 'xml'];
  if (images.contains(ext)) return _DocKind.image;
  if (ext == 'pdf') return _DocKind.pdf;
  if (office.contains(ext)) return _DocKind.office;
  if (texts.contains(ext)) return _DocKind.text;
  return _DocKind.other;
}

String _formatSize(dynamic bytes) {
  final b = int.tryParse('${bytes ?? 0}') ?? 0;
  if (b <= 0) return '—';
  if (b < 1024) return '$b B';
  if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1048576).toStringAsFixed(1)} MB';
}

/// Full-screen document viewer that mirrors the web premium viewer.
/// Handles images (zoom/pan/rotate), PDF (native), office docs (Google Docs
/// viewer via WebView), text files, and a fallback for unsupported types.
class HomecareDocumentViewer extends StatefulWidget {
  final String url;
  final String name;
  final String? fileType;
  final int? fileSize;

  const HomecareDocumentViewer({
    super.key,
    required this.url,
    required this.name,
    this.fileType,
    this.fileSize,
  });

  @override
  State<HomecareDocumentViewer> createState() => _HomecareDocumentViewerState();
}

class _HomecareDocumentViewerState extends State<HomecareDocumentViewer> {
  late final _DocKind _kind;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _kind = _classify(widget.fileType, widget.url);
    if (_kind == _DocKind.office) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (p == 100) setState(() {});
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.url)}&embedded=true',
        ));
    }
  }

  String get _fileTypeLabel =>
      (widget.fileType?.isNotEmpty == true ? widget.fileType!.toUpperCase() : 'FILE');

  void _openExternal() =>
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('$_fileTypeLabel · ${_formatSize(widget.fileSize)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open externally',
            onPressed: _openExternal,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_kind) {
      case _DocKind.image:
        return _ImageViewer(url: widget.url);
      case _DocKind.pdf:
        return _PdfViewer(url: widget.url);
      case _DocKind.office:
        return _OfficeViewer(controller: _webController);
      case _DocKind.text:
        return _TextViewer(url: widget.url);
      case _DocKind.other:
        return _FallbackViewer(
          name: widget.name,
          fileType: _fileTypeLabel,
          size: _formatSize(widget.fileSize),
          onDownload: _openExternal,
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════════
//  Image viewer — zoom / pan / rotate via InteractiveViewer
// ═════════════════════════════════════════════════════════════════
class _ImageViewer extends StatefulWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final TransformationController _tc = TransformationController();
  double _rotation = 0;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 0.2,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(80),
            child: Center(
              child: Transform.rotate(
                angle: _rotation * 3.14159265 / 180,
                child: Image.network(
                  widget.url,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1),
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (ctx, e, _) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: 56, color: Colors.white54),
                        SizedBox(height: 8),
                        Text('Could not load image',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Floating controls
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _ctrlBtn(Icons.rotate_left_rounded, 'Rotate left', () {
                  setState(() => _rotation = (_rotation - 90) % 360);
                }),
                _ctrlBtn(Icons.rotate_right_rounded, 'Rotate right', () {
                  setState(() => _rotation = (_rotation + 90) % 360);
                }),
                const SizedBox(width: 4),
                Container(
                    width: 1, height: 20, color: Colors.white24),
                const SizedBox(width: 4),
                _ctrlBtn(Icons.zoom_in_rounded, 'Zoom in', () {
                  _tc.value = _tc.value * (1.2);
                }),
                _ctrlBtn(Icons.zoom_out_rounded, 'Zoom out', () {
                  _tc.value = _tc.value * (0.8);
                }),
                _ctrlBtn(Icons.fit_screen_rounded, 'Fit', () {
                  _tc.value = Matrix4.identity();
                  setState(() => _rotation = 0);
                }),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ctrlBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  PDF viewer — renders via Syncfusion Flutter PDF Viewer
// ═════════════════════════════════════════════════════════════════
class _PdfViewer extends StatefulWidget {
  final String url;
  const _PdfViewer({required this.url});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  final _controller = PdfViewerController();
  int? _pages;
  int _currentPage = 1;
  bool _loading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SfPdfViewer.network(
          widget.url,
          controller: _controller,
          onPageChanged: (details) {
            if (mounted) setState(() => _currentPage = details.newPageNumber);
          },
          onDocumentLoaded: (details) {
            if (mounted) {
              setState(() {
                _pages = _controller.pageCount;
                _loading = false;
              });
            }
          },
          onDocumentLoadFailed: (details) {
            if (mounted) {
              setState(() {
                _error = details.description;
                _loading = false;
              });
            }
          },
        ),
        if (_loading && _error == null)
          const Center(child: CircularProgressIndicator(color: hcTeal)),
        if (_error != null)
          _FallbackMessage(
            icon: Icons.picture_as_pdf_rounded,
            message: _error!,
            onOpenExternal: () => launchUrl(
                Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
        if (_pages != null && _error == null)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$_currentPage / $_pages',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Office viewer — Google Docs viewer in a WebView
// ═════════════════════════════════════════════════════════════════
class _OfficeViewer extends StatefulWidget {
  final WebViewController? controller;
  const _OfficeViewer({required this.controller});

  @override
  State<_OfficeViewer> createState() => _OfficeViewerState();
}

class _OfficeViewerState extends State<_OfficeViewer> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller?.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onProgress: (p) {
          if (p > 90 && mounted) setState(() => _loading = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null) {
      return const Center(child: Text('WebView not available'));
    }
    return Stack(
      children: [
        WebViewWidget(controller: widget.controller!),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: hcTeal)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Text viewer — download and render as scrollable text
// ═════════════════════════════════════════════════════════════════
class _TextViewer extends StatefulWidget {
  final String url;
  const _TextViewer({required this.url});

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String? _content;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Dio().get<String>(widget.url);
      if (mounted) {
        setState(() {
          _content = res.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load file: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: hcTeal));
    }
    if (_error != null) {
      return _FallbackMessage(
        icon: Icons.description_rounded,
        message: _error!,
        onOpenExternal: () => launchUrl(
            Uri.parse(widget.url), mode: LaunchMode.externalApplication),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content ?? '',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Fallback for unsupported file types
// ═════════════════════════════════════════════════════════════════
class _FallbackViewer extends StatelessWidget {
  final String name;
  final String fileType;
  final String size;
  final VoidCallback onDownload;
  const _FallbackViewer({
    required this.name,
    required this.fileType,
    required this.size,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hcTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.insert_drive_file_rounded,
                  size: 56, color: hcTeal),
            ),
            const SizedBox(height: 16),
            Text('Preview not available',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('$fileType · $size',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: hcTeal),
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download / Open with…'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline fallback message with an "open externally" action.
class _FallbackMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onOpenExternal;
  const _FallbackMessage({
    required this.icon,
    required this.message,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open externally'),
            ),
          ],
        ),
      ),
    );
  }
}
