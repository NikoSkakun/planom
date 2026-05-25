import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
      await _shareAsPdf(title: fallbackTitle, content: content);
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

Future<void> _shareAsPdf({
  required String title,
  required String content,
}) async {
  // Built-in PDF fonts (Helvetica) cover only the basic Latin range, so any
  // emoji, Cyrillic, CJK or other non-Latin glyph would render as a tofu
  // box. Load Noto Sans for the body text and Noto Color Emoji as a
  // fallback so the document keeps the user's original characters.
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final emoji = await PdfGoogleFonts.notoColorEmoji();

  final doc = pw.Document(
    title: title,
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [emoji],
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
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            fontFallback: [emoji],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          content,
          style: pw.TextStyle(
            fontSize: 12,
            lineSpacing: 4,
            fontFallback: [emoji],
          ),
        ),
      ],
    ),
  );
  final bytes = await doc.save();
  final dir = await getTemporaryDirectory();
  final fileName = '${_sanitizeFileName(title)}.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], subject: title);
}

Future<void> _shareAsImage(
  BuildContext context, {
  required String title,
  required String content,
}) async {
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
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        final dir = await getTemporaryDirectory();
        final fileName = '${_sanitizeFileName(title)}.png';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], subject: title);
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
