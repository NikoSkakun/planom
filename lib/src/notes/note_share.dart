import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
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

/// Caches the bundled font byte data after the first PDF export, so
/// subsequent shares don't re-read the same assets from disk.
class _FontCache {
  static ByteData? _regular;
  static ByteData? _bold;
  static ByteData? _emoji;

  static Future<ByteData> regular() async =>
      _regular ??= await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  static Future<ByteData> bold() async =>
      _bold ??= await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  static Future<ByteData?> emoji() async {
    if (_emoji != null) return _emoji;
    try {
      return _emoji = await rootBundle.load('assets/fonts/NotoEmoji.ttf');
    } catch (_) {
      return null;
    }
  }
}

Future<void> _shareAsPdf(
  BuildContext rootContext, {
  required String title,
  required String content,
}) async {
  final progress = _ProgressController();
  // Show a modal progress sheet so the user knows something is happening
  // and can bail out if it's taking too long.
  _showProgress(rootContext, progress: progress, label: S.of(rootContext).preparingPdf);

  Future<void> run() async {
    try {
      // 1) Load Unicode-capable fonts bundled with the app. Reading from
      //    rootBundle is fast and works offline — no flaky CDN downloads.
      final regularBytes = await _FontCache.regular();
      if (progress.isCanceled) return;
      final boldBytes = await _FontCache.bold();
      if (progress.isCanceled) return;
      final emojiBytes = await _FontCache.emoji();
      if (progress.isCanceled) return;

      final regular = pw.Font.ttf(regularBytes);
      final bold = pw.Font.ttf(boldBytes);
      final emoji = emojiBytes == null ? null : pw.Font.ttf(emojiBytes);
      final fallback = emoji == null ? <pw.Font>[] : <pw.Font>[emoji];

      // 2) Build the document.
      final doc = pw.Document(
        title: title,
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
          fontFallback: fallback,
        ),
      );
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: bold,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                fontFallback: fallback,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              content,
              style: pw.TextStyle(
                font: regular,
                fontSize: 12,
                lineSpacing: 4,
                fontFallback: fallback,
              ),
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      if (progress.isCanceled) return;

      // 3) Persist to a temp file. Using `flush: true` so the bytes are
      //    fsynced before we hand them to the share sheet.
      final dir = await getTemporaryDirectory();
      final fileName = '${_sanitizeFileName(title)}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (progress.isCanceled) return;

      // 4) Hide the progress dialog before opening the share sheet so the
      //    user sees the system share UI immediately.
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

  // Kick the work off but don't await it here — the progress dialog is
  // already on screen and its cancel button will short-circuit run() by
  // flipping progress.isCanceled.
  unawaited(run());
}

Future<void> _shareAsImage(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final progress = _ProgressController();
  _showProgress(context, progress: progress, label: S.of(context).preparingImage);

  // Render the note off-screen using the same MarkdownView the live preview
  // uses, then capture a PNG via RepaintBoundary.toImage. The widget needs
  // to live inside a real tree to paint, so we mount it in a hidden overlay
  // entry positioned off-screen.
  final key = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  final pixelRatio =
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  const width = 800.0;
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) {
      return Positioned(
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
      );
    },
  );
  overlay.insert(entry);
  // Wait two frames so layout + paint finish before we ask for the image.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (progress.isCanceled) return;
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        if (progress.isCanceled) return;
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (progress.isCanceled) return;
        final bytes = byteData!.buffer.asUint8List();
        final dir = await getTemporaryDirectory();
        final fileName = '${_sanitizeFileName(title)}.png';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        if (progress.isCanceled) return;
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
      } finally {
        entry.remove();
        completer.complete();
      }
    });
  });
  await completer.future;
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
            onTap: () {},
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

