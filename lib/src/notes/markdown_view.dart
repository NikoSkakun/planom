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
  /// link — used by the host to switch into edit mode.
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final linkColor = CupertinoColors.activeBlue.resolveFrom(context);
    final mutedBg = CupertinoColors.systemGrey6.resolveFrom(context);
    final mutedBorder = CupertinoColors.systemGrey4.resolveFrom(context);

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
      p: base.copyWith(fontSize: 16, height: 1.35),
      h1: base.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
      h2: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      h3: base.copyWith(fontSize: 19, fontWeight: FontWeight.w600),
      strong: base.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      em: base.copyWith(fontStyle: FontStyle.italic, fontSize: 16),
      del: base.copyWith(
          decoration: TextDecoration.lineThrough, fontSize: 16),
      a: base.copyWith(color: linkColor, fontSize: 16),
      code: base.copyWith(
        fontFamily: 'Menlo',
        fontSize: 14,
        backgroundColor: mutedBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: mutedBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mutedBorder, width: 0.5),
      ),
      blockquote: base.copyWith(
        fontSize: 16,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 3, color: mutedBorder),
        ),
      ),
      listBullet: base.copyWith(fontSize: 16),
      blockSpacing: 10,
    );

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
                data: data,
                selectable: false,
                fitContent: true,
                styleSheet: styleSheet,
                softLineBreak: true,
                onTapLink: (text, href, title) => _openLink(href),
              ),
            ),
          )
        : Markdown(
            data: data,
            selectable: false,
            padding: padding,
            styleSheet: styleSheet,
            softLineBreak: true,
            onTapLink: (text, href, title) => _openLink(href),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
