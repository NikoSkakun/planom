import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../localization/strings.dart';
import '../utils/selection_menu.dart';
import 'markdown_view.dart';

enum NoteShareFormat { text, pdf, image }

/// Opens a menu for picking the share format. The caller passes the title
/// and content from the note's live editor state (NOT the persisted Note),
/// so an in-progress edit is what gets shared.
Future<void> showNoteShareMenu(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final s = S.of(context);
  final fallbackTitle = title.trim().isEmpty ? s.untitled : title.trim();
  final choice = await showSelectionMenu<NoteShareFormat>(
    context: context,
    title: s.share,
    // Opened from the note's nav-bar ⋯ menu → anchor in the same top-right
    // spot so the format picker visually replaces the parent dropdown.
    anchor: SelectionMenuAnchor.topRight,
    options: [
      SelectionMenuOption(
        value: NoteShareFormat.text,
        label: s.shareAsText,
        icon: CupertinoIcons.text_alignleft,
      ),
      SelectionMenuOption(
        value: NoteShareFormat.pdf,
        label: s.shareAsPdf,
        icon: CupertinoIcons.doc_richtext,
      ),
      SelectionMenuOption(
        value: NoteShareFormat.image,
        label: s.shareAsImage,
        icon: CupertinoIcons.photo,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case NoteShareFormat.text:
      await _shareAsText(title: fallbackTitle, content: content);
      break;
    case NoteShareFormat.pdf:
      await _shareAsPdf(context, title: fallbackTitle, content: content);
      break;
    case NoteShareFormat.image:
      if (!context.mounted) return;
      await _shareAsImage(context, title: fallbackTitle, content: content);
      break;
  }
}

Future<void> _shareAsText({
  required String title,
  required String content,
}) async {
  final body = content.trim().isEmpty ? title : '$title\n\n$content';
  await Share.share(body, subject: title);
}

Future<void> _shareAsPdf(
  BuildContext rootContext, {
  required String title,
  required String content,
}) async {
  final progress = _ProgressController();
  // Show a modal progress sheet so the user knows something is happening
  // and can bail out if it's taking too long.
  _showProgress(rootContext,
      progress: progress, label: S.of(rootContext).preparingPdf);

  try {
    // Render the note through the very same MarkdownView the app displays,
    // then slice the resulting bitmap into A4 pages. Going through a bitmap
    // (rather than emitting pw.Text) is what makes the PDF match what the
    // user sees: headings, tables, task lists, LaTeX, emoji and non-Latin
    // scripts all survive — none of which the pdf package's built-in Type-1
    // fonts can represent.
    final rendered = await _renderNoteToImage(
      rootContext,
      title: title,
      content: content,
      progress: progress,
    );
    if (rendered == null || progress.isCanceled) {
      rendered?.dispose();
      progress.close();
      // A render that failed (rather than one the user cancelled) should say
      // so instead of just closing the sheet.
      if (rendered == null && !progress.isCanceled && rootContext.mounted) {
        _showError(rootContext, message: S.of(rootContext).exportFailed);
      }
      return;
    }

    final doc = pw.Document(title: title);
    // Slice height must match the shape of the box the image is actually
    // drawn into — the A4 page minus OUR margin, not the format's own default
    // margin. Get that wrong and `fitWidth` scales each slice past the
    // content height, cropping a band off every page.
    const margin = 24.0;
    final contentWidth = PdfPageFormat.a4.width - margin * 2;
    final contentHeight = PdfPageFormat.a4.height - margin * 2;
    final sliceHeight = (rendered.width * (contentHeight / contentWidth))
        .floor()
        .clamp(1, 1 << 20);
    const maxPages = 60; // hard stop so a pathological note can't hang here
    var top = 0;
    var pages = 0;
    while (top < rendered.height && pages < maxPages) {
      if (progress.isCanceled) {
        rendered.dispose();
        progress.close();
        return;
      }
      final height = (top + sliceHeight > rendered.height)
          ? rendered.height - top
          : sliceHeight;
      final slice = await _cropImage(rendered, top, height);
      final image = pw.MemoryImage(slice);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(margin),
          build: (context) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(image, fit: pw.BoxFit.fitWidth),
          ),
        ),
      );
      top += height;
      pages++;
    }
    rendered.dispose();

    final bytes = await doc.save();
    if (progress.isCanceled) {
      progress.close();
      return;
    }

    // Persist to a temp file. `flush: true` fsyncs the bytes before
    // handing the path to the share sheet.
    final dir = await getTemporaryDirectory();
    final fileName = '${_sanitizeFileName(title)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (progress.isCanceled) {
      progress.close();
      return;
    }

    // Hide the progress dialog before opening the share sheet so the
    // user sees the system share UI immediately.
    progress.close();

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
      subject: title,
    );
  } catch (e, st) {
    debugPrint('Note PDF export failed: $e\n$st');
    progress.close();
    if (rootContext.mounted) {
      _showError(rootContext, message: '$e');
    }
  }
}

/// Mounts the note off-screen (an overlay entry parked far to the left) and
/// captures it as an image. Shared by the PDF and PNG exports.
Future<ui.Image?> _renderNoteToImage(
  BuildContext context, {
  required String title,
  required String content,
  required _ProgressController progress,
  double width = 800,
  double pixelRatio = 2,
}) async {
  if (!context.mounted) return null;
  final key = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<ui.Image?>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
        child: SizedBox(
          width: width,
          child: RepaintBoundary(
            key: key,
            child: _NotePosterBody(title: title, content: content),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  // Wait two frames so layout + paint finish before asking for the image.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (progress.isCanceled) {
          completer.complete(null);
          return;
        }
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        completer.complete(await boundary.toImage(pixelRatio: pixelRatio));
      } catch (e, st) {
        debugPrint('Note render failed: $e\n$st');
        completer.complete(null);
      } finally {
        entry.remove();
      }
    });
  });
  return completer.future;
}

/// Returns PNG bytes for the horizontal band of [source] starting at [top].
Future<Uint8List> _cropImage(ui.Image source, int top, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    Rect.fromLTWH(
        0, top.toDouble(), source.width.toDouble(), height.toDouble()),
    Rect.fromLTWH(0, 0, source.width.toDouble(), height.toDouble()),
    Paint(),
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(source.width, height);
  picture.dispose();
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  cropped.dispose();
  return data!.buffer.asUint8List();
}

Future<void> _shareAsImage(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final progress = _ProgressController();
  _showProgress(context, progress: progress, label: S.of(context).preparingImage);

  try {
    // Same off-screen render the PDF path uses, at the device's own pixel
    // ratio so the PNG is crisp on the sharing device.
    final pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final image = await _renderNoteToImage(
      context,
      title: title,
      content: content,
      progress: progress,
      pixelRatio: pixelRatio,
    );
    if (image == null || progress.isCanceled) {
      image?.dispose();
      progress.close();
      if (image == null && !progress.isCanceled && context.mounted) {
        _showError(context, message: S.of(context).exportFailed);
      }
      return;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null || progress.isCanceled) {
      progress.close();
      return;
    }
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final fileName = '${_sanitizeFileName(title)}.png';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (progress.isCanceled) {
      progress.close();
      return;
    }
    progress.close();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: fileName)],
      subject: title,
    );
  } catch (e, st) {
    debugPrint('Note image export failed: $e\n$st');
    progress.close();
    if (context.mounted) {
      _showError(context, message: '$e');
    }
  }
}

String _sanitizeFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
      .trim();
  if (cleaned.isEmpty) return 'note';
  if (cleaned.length > 60) return cleaned.substring(0, 60);
  return cleaned;
}

class _NotePosterBody extends StatelessWidget {
  const _NotePosterBody({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 14),
          MarkdownView(
            data: content,
            onTap: (_) {},
            shrinkWrap: true,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Shared between the long-running export and the dialog: holds the
/// cancel flag and a callback to dismiss the modal once.
class _ProgressController {
  bool isCanceled = false;
  VoidCallback? _dismiss;

  void attachDismiss(VoidCallback dismiss) {
    if (_dismiss != null) return;
    _dismiss = dismiss;
  }

  /// Marks the operation canceled and tears the dialog down.
  void cancel() {
    isCanceled = true;
    close();
  }

  /// Closes the dialog without flipping the cancel flag — used by the
  /// success path right before opening the share sheet so the user
  /// doesn't see the loader behind the system UI.
  void close() {
    final d = _dismiss;
    _dismiss = null;
    d?.call();
  }
}

void _showProgress(
  BuildContext context, {
  required _ProgressController progress,
  required String label,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  bool popped = false;
  void dismiss() {
    if (popped) return;
    popped = true;
    if (navigator.canPop()) navigator.pop();
  }

  progress.attachDismiss(dismiss);

  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ProgressDialog(
      label: label,
      onCancel: progress.cancel,
    ),
  );
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoAlertDialog(
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: onCancel,
          isDestructiveAction: true,
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

void _showError(BuildContext context, {required String message}) {
  final s = S.of(context);
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(s.exportFailed),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.ok),
        ),
      ],
    ),
  );
}

