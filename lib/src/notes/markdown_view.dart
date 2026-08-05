import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/emoji_text.dart';
import 'markdown_math.dart';

/// Renders markdown to a view with tappable links.
///
/// Parses the full CommonMark grammar plus the GitHub-flavoured web extension
/// set — tables, task lists, strikethrough, footnotes, autolinks, heading ids,
/// alert blocks and `:emoji:` shortcodes — and LaTeX via `\$…\$` / `\$\$…\$\$`
/// (see markdown_math.dart).
///
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
      h4: pStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      h5: pStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      h6: pStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      h1Padding: const EdgeInsets.only(top: 14),
      h2Padding: const EdgeInsets.only(top: 12),
      h3Padding: const EdgeInsets.only(top: 10),
      h4Padding: const EdgeInsets.only(top: 10),
      h5Padding: const EdgeInsets.only(top: 8),
      h6Padding: const EdgeInsets.only(top: 8),
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
      listIndent: 22,
      // GFM tables — unstyled by default, which rendered them with the
      // package's Material fallback.
      tableHead: pStyle.copyWith(fontWeight: FontWeight.w700),
      tableBody: pStyle,
      tableHeadAlign: TextAlign.start,
      tableBorder: TableBorder.all(color: mutedBorder, width: 0.5),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      tablePadding: const EdgeInsets.only(top: 10, bottom: 4),
      blockquotePadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      codeblockPadding: const EdgeInsets.all(10),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(width: 1, color: mutedBorder)),
      ),
      // 0 means consecutive bullets / numbered items stack with no extra gap,
      // matching the editor (where each list line is just a newline). Inter-
      // paragraph spacing is handled by pPadding above so paragraphs still
      // get a visible break.
      blockSpacing: 0,
    );

    final source = preserveMarkdownBlankLines(data);
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
                extensionSet: md.ExtensionSet.gitHubWeb,
                inlineSyntaxes: _inlineSyntaxes(),
                builders: _builders(),
                checkboxBuilder: (checked) => _TaskCheckbox(checked: checked),
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
            extensionSet: md.ExtensionSet.gitHubWeb,
            inlineSyntaxes: _inlineSyntaxes(),
            builders: _builders(),
            checkboxBuilder: (checked) => _TaskCheckbox(checked: checked),
            onTapLink: (text, href, title) => _openLink(href),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onTap(details.localPosition),
      child: body,
    );
  }

  /// Emoji presentation + LaTeX, on top of the gitHubWeb extension set.
  /// Explicit syntaxes are parsed before the extension set's, so `\$…\$` wins
  /// over anything the extensions might read a `\$` as.
  static List<md.InlineSyntax> _inlineSyntaxes() => [
        EmojiInlineSyntax(),
        ...mathInlineSyntaxes(),
      ];

  static Map<String, MarkdownElementBuilder> _builders() => {
        'emoji': EmojiElementBuilder(),
        ...mathBuilders(),
      };
}

/// GFM task-list checkbox (`- [x] done`), drawn in the app's own style
/// instead of the package's Material fallback. Read-only: the note's text is
/// the source of truth, so ticking happens by editing the line.
class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 2),
      child: Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          color: checked ? AppColors.systemGreen : null,
          borderRadius: BorderRadius.circular(5),
          border: checked
              ? null
              : Border.all(
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  width: 1.5,
                ),
        ),
        child: checked
            ? const Icon(CupertinoIcons.checkmark,
                size: 12, color: CupertinoColors.white)
            : null,
      ),
    );
  }
}

/// Markdown collapses any run of consecutive blank lines into a single
/// paragraph break, so a note with deliberate vertical spacing renders
/// without it. Walk through [input] line-by-line and, for every blank line
/// past the first in a run, insert a no-break-space paragraph so the renderer
/// keeps the gap.
///
/// Lines inside a fenced code block — or inside a `$$ … $$` / `\[ … \]`
/// display-math block — are passed through unchanged, since splitting either
/// one would corrupt it. Math delimiters are **paired up first**: a lone `$$`
/// with no partner is treated as ordinary text rather than swallowing the
/// whole rest of the note.
String preserveMarkdownBlankLines(String input) {
  final lines = input.split('\n');
  final protected = _protectedLines(lines);
  final out = <String>[];
  var blankRun = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (protected.contains(i)) {
      blankRun = 0;
      out.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      blankRun++;
      if (blankRun == 1) {
        out.add('');
      } else {
        // A no-break space so the spacer paragraph isn't trimmed away.
        out.add('\u00A0');
        out.add('');
      }
    } else {
      blankRun = 0;
      out.add(line);
    }
  }
  return out.join('\n');
}

/// Indices of lines that must be copied through verbatim: fenced code blocks
/// (including their fences) and balanced display-math blocks.
Set<int> _protectedLines(List<String> lines) {
  final codeFence = RegExp(r'^\s*(```|~~~)');
  final mathToggle = RegExp(r'^\s*\$\$\s*$');
  final mathOpen = RegExp(r'^\s*\\\[\s*$');
  final mathClose = RegExp(r'^\s*\\\]\s*$');

  final protected = <int>{};
  var i = 0;
  while (i < lines.length) {
    if (codeFence.hasMatch(lines[i])) {
      protected.add(i);
      var j = i + 1;
      while (j < lines.length && !codeFence.hasMatch(lines[j])) {
        protected.add(j);
        j++;
      }
      // An unterminated fence protects the rest of the note, which matches
      // how markdown itself reads it.
      if (j < lines.length) protected.add(j);
      i = j + 1;
      continue;
    }
    final isToggle = mathToggle.hasMatch(lines[i]);
    if (isToggle || mathOpen.hasMatch(lines[i])) {
      final closer = isToggle ? mathToggle : mathClose;
      var j = i + 1;
      while (j < lines.length &&
          !closer.hasMatch(lines[j]) &&
          !codeFence.hasMatch(lines[j])) {
        j++;
      }
      // Only a *balanced* pair counts; a stray delimiter is just text.
      if (j < lines.length && closer.hasMatch(lines[j])) {
        for (var k = i; k <= j; k++) {
          protected.add(k);
        }
        i = j + 1;
        continue;
      }
    }
    i++;
  }
  return protected;
}
