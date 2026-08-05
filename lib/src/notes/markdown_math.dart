import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// LaTeX support for the app's markdown.
///
/// Two inline syntaxes feed one element builder:
///   * `$$…$$` / `\[…\]` → display math, rendered centred on its own line
///   * `$…$`   / `\(…\)` → inline math, rendered in the run of text
///
/// Both are **inline** syntaxes even though display math reads like a block.
/// That is deliberate: flutter_markdown registers block-level builders into a
/// package-global tag list on every build and never removes them, so a block
/// builder would grow that list for the lifetime of the process. A display
/// formula sitting in its own paragraph parses identically as an inline
/// element whose parent paragraph contains nothing else.
///
/// Malformed TeX never throws — [Math.tex] catches parse errors and hands them
/// to the fallback, which shows the author their own source in red.
const String kMathTag = 'math';
const String kDisplayMathTag = 'mathDisplay';

/// `$$…$$` and `\[…\]`. Registered before [MathInlineSyntax] so a `$$` opener
/// is never mistaken for an empty `$…$`.
class DisplayMathSyntax extends md.InlineSyntax {
  DisplayMathSyntax()
      : super(
          r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = (match[1] ?? match[2] ?? '').trim();
    if (tex.isEmpty) return false;
    parser.addNode(md.Element.text(kDisplayMathTag, tex));
    return true;
  }
}

/// `$…$` and `\(…\)`.
///
/// The `$` form is deliberately conservative, because notes contain far more
/// prices than formulas. To open, the `$` must be unescaped and followed by
/// neither whitespace nor a digit; to close, the `$` must not be preceded by
/// whitespace nor followed by a digit. That leaves `$50-$80`, `US$5`, `$5/$10`
/// and "it cost $5 and $7" as plain prose, while `$x^2$` is math. A formula
/// that genuinely starts with a digit needs the `\(…\)` form (or `$$…$$`).
///
/// The body also excludes backticks so a formula can never swallow an inline
/// code span — custom inline syntaxes are tried before the package's own, so
/// without that guard `` $b `c$` `` would eat the code.
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax()
      : super(
          r'(?<!\\)\$(?![\s\d])((?:[^$\n\\`]|\\.)+?)(?<![\s\\])\$(?!\d)'
          r'|\\\(([\s\S]+?)\\\)',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = (match[1] ?? match[2] ?? '').trim();
    if (tex.isEmpty) return false;
    parser.addNode(md.Element.text(kMathTag, tex));
    return true;
  }
}

/// Renders a `math` / `mathDisplay` element.
///
/// Returns `Text.rich` with a [WidgetSpan] rather than a bare [Math] widget:
/// flutter_markdown only merges Text/RichText/SelectableText back into the
/// surrounding paragraph span, so anything else would break out of the line
/// and lose its baseline.
class MathElementBuilder extends MarkdownElementBuilder {
  MathElementBuilder({required this.display});

  /// Display math gets the larger [MathStyle.display] treatment and a little
  /// vertical breathing room; inline math sits in the text run.
  final bool display;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = preferredStyle ?? parentStyle;
    final tex = element.textContent;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: display
                ? PlaceholderAlignment.middle
                : PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: display
                  ? const EdgeInsets.symmetric(vertical: 6)
                  : EdgeInsets.zero,
              child: Math.tex(
                tex,
                mathStyle: display ? MathStyle.display : MathStyle.text,
                textStyle: style,
                onErrorFallback: (error) => _MathError(
                  tex: tex,
                  style: style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of a formula the TeX parser rejected: the author's own
/// source, tinted red, so the mistake is findable without a console.
class _MathError extends StatelessWidget {
  const _MathError({required this.tex, this.style});

  final String tex;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      tex,
      style: (style ?? const TextStyle()).copyWith(
        fontFamily: 'Menlo',
        color: CupertinoColors.systemRed.resolveFrom(context),
      ),
    );
  }
}

/// The inline syntaxes to hand to `MarkdownBody`/`Markdown`, in priority
/// order (display before inline).
List<md.InlineSyntax> mathInlineSyntaxes() => [
      DisplayMathSyntax(),
      MathInlineSyntax(),
    ];

/// The element builders that pair with [mathInlineSyntaxes].
Map<String, MarkdownElementBuilder> mathBuilders() => {
      kDisplayMathTag: MathElementBuilder(display: true),
      kMathTag: MathElementBuilder(display: false),
    };
