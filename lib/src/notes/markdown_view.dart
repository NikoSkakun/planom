import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders markdown to a view with tappable links.
/// Supports web (http/https), email (mailto:), telephone (tel:), and any
/// custom app URL scheme (myapp://...) — anything `url_launcher` can resolve.
///
/// When [shrinkWrap] is true, the view sizes to its content (no internal
/// scrolling) — use this inside a parent scroll view such as a ListView.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.data,
    required this.onTap,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  /// Raw markdown text.
  final String data;

  /// Called when the user taps anywhere on the rendered surface that isn't a
  /// link — used by the host to switch into edit mode. The argument is the
  /// local position of the tap inside the rendered surface, including the
  /// configured [padding]; callers that don't care about the position can
  /// ignore it.
  final ValueChanged<Offset> onTap;

  /// When true, renders as a non-scrolling block sized to its content.
  final bool shrinkWrap;

  /// Padding around the rendered markdown.
  final EdgeInsets padding;

  Future<void> _openLink(String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Markdown collapses any run of consecutive blank lines into a single
  /// paragraph break, so a note with deliberate vertical spacing renders
  /// without it. Walk through [input] line-by-line and, for every blank
  /// line past the first in a run, insert a non-breaking-space paragraph
  /// so the renderer keeps the gap. Lines inside a fenced code block are
  /// passed through unchanged.
  static String _preserveBlankLines(String input) {
    final lines = input.split('\n');
    final out = <String>[];
    int blankRun = 0;
    bool inCodeBlock = false;
    final fence = RegExp(r'^\s*(```|~~~)');
    for (final line in lines) {
      if (fence.hasMatch(line)) {
        inCodeBlock = !inCodeBlock;
        blankRun = 0;
        out.add(line);
        continue;
      }
      if (inCodeBlock) {
        out.add(line);
        continue;
      }
      if (line.trim().isEmpty) {
        blankRun++;
        if (blankRun == 1) {
          out.add('');
        } else {
          out.add(' ');
          out.add('');
        }
      } else {
        blankRun = 0;
        out.add(line);
      }
    }
    return out.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final linkColor = CupertinoColors.activeBlue.resolveFrom(context);
    final mutedBg = CupertinoColors.systemGrey6.resolveFrom(context);
    final mutedBorder = CupertinoColors.systemGrey4.resolveFrom(context);

    // Single text style shared by paragraphs, list-item bodies and bullets so
    // the rendered view matches the editor (CupertinoTextField with the same
    // 16 / 1.35 metrics) — without this the bullet defaults to whatever the
    // theme provides (no explicit height) and its baseline drifts relative to
    // the surrounding text, making the line look taller in render than in
    // edit mode.
    final pStyle = base.copyWith(fontSize: 16, height: 1.35);

    final styleSheet = MarkdownStyleSheet(
      // Force left-aligned text. Some MarkdownStyleSheet defaults wrap
      // paragraph contents in a Wrap whose alignment otherwise pushes single
      // lines into the middle of the row.
      textAlign: WrapAlignment.start,
      h1Align: WrapAlignment.start,
      h2Align: WrapAlignment.start,
      h3Align: WrapAlignment.start,
      h4Align: WrapAlignment.start,
      h5Align: WrapAlignment.start,
      h6Align: WrapAlignment.start,
      unorderedListAlign: WrapAlignment.start,
      orderedListAlign: WrapAlignment.start,
      blockquoteAlign: WrapAlignment.start,
      codeblockAlign: WrapAlignment.start,
      p: pStyle,
      // Restore paragraph breathing room by adding a top gap. Combined with
      // blockSpacing: 0 below, this keeps paragraphs visually separated
      // without inflating the gap between consecutive list items (which
      // share a single parent and don't get pPadding).
      pPadding: const EdgeInsets.only(top: 8),
      h1: pStyle.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
      h2: pStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      h3: pStyle.copyWith(fontSize: 19, fontWeight: FontWeight.w600),
      strong: pStyle.copyWith(fontWeight: FontWeight.w700),
      em: pStyle.copyWith(fontStyle: FontStyle.italic),
      del: pStyle.copyWith(decoration: TextDecoration.lineThrough),
      a: pStyle.copyWith(color: linkColor),
      code: pStyle.copyWith(
        fontFamily: 'Menlo',
        fontSize: 14,
        backgroundColor: mutedBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: mutedBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mutedBorder, width: 0.5),
      ),
      blockquote: pStyle.copyWith(
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 3, color: mutedBorder),
        ),
      ),
      listBullet: pStyle,
      listBulletPadding: const EdgeInsets.only(right: 6),
      // 0 means consecutive bullets / numbered items stack with no extra gap,
      // matching the editor (where each list line is just a newline). Inter-
      // paragraph spacing is handled by pPadding above so paragraphs still
      // get a visible break.
      blockSpacing: 0,
    );

    final source = _preserveBlankLines(data);
    final body = shrinkWrap
        ? Padding(
            padding: padding,
            // Force the MarkdownBody to lay out at its intrinsic size from
            // the leading edge. Without this, some host layouts that hand
            // MarkdownBody loose vertical constraints (e.g. the note editor's
            // ConstrainedBox with `minHeight: viewport`) leave the body
            // visually centered inside the spare space.
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: MarkdownBody(
                data: source,
                selectable: false,
                fitContent: true,
                styleSheet: styleSheet,
                softLineBreak: true,
                onTapLink: (text, href, title) => _openLink(href),
              ),
            ),
          )
        : Markdown(
            data: source,
            selectable: false,
            padding: padding,
            styleSheet: styleSheet,
            softLineBreak: true,
            onTapLink: (text, href, title) => _openLink(href),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onTap(details.localPosition),
      child: body,
    );
  }
}
