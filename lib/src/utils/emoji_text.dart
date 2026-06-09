import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Emoji-capable font families, in platform-preference order. The first family
/// that exists on the running platform is used; the rest act as fallbacks so
/// the same style works everywhere.
///
/// Forcing one of these for emoji runs is what makes "text-default" emoji
/// (a base symbol followed by the U+FE0F emoji variation selector, e.g. the
/// warning sign, heart, sun, pencil) render as colour emoji. Without it the
/// surrounding reading font (San Francisco, or a Google font) already supplies
/// a monochrome glyph for the base character, so Flutter renders that text
/// glyph and never falls back to the emoji font — the variation selector is
/// effectively ignored.
const List<String> kEmojiFontFallback = <String>[
  'Apple Color Emoji', // iOS, macOS
  'Noto Color Emoji', // Android, Linux, Fuchsia
  'Segoe UI Emoji', // Windows
  'Noto Emoji', // last-resort monochrome
];

/// Returns [base] adjusted so its glyphs are drawn from an emoji font.
TextStyle _emojiStyle(TextStyle base) => base.copyWith(
      fontFamily: kEmojiFontFallback.first,
      fontFamilyFallback: kEmojiFontFallback.sublist(1),
    );

/// True when [cluster] (a single grapheme cluster) should be drawn with an
/// emoji font. We treat a cluster as emoji when it:
///  - carries the emoji variation selector U+FE0F (the text-default → emoji
///    presentation request — this is the case that was rendering as plain
///    monochrome text),
///  - is a keycap (combining enclosing keycap U+20E3) or part of a ZWJ
///    sequence (U+200D), or
///  - contains a code point on an emoji plane (high surrogate U+D83C–U+D83E,
///    covering U+1F000–U+1FBFF: faces, symbols, flags via regional
///    indicators, etc.).
///
/// Bare BMP symbols without U+FE0F (e.g. a literal arrow, check mark or
/// trademark sign) are left in the surrounding text font on purpose: they have
/// no colour-emoji glyph and forcing an emoji font would turn them into tofu.
bool _clusterIsEmoji(String cluster) {
  for (final unit in cluster.codeUnits) {
    if (unit == 0xFE0F || unit == 0x20E3 || unit == 0x200D) return true;
    if (unit >= 0xD83C && unit <= 0xD83E) return true;
  }
  return false;
}

/// Splits [text] into inline spans, drawing emoji clusters with an emoji font
/// while leaving the rest in [base]. Consecutive clusters of the same kind are
/// coalesced into a single span so the result stays compact.
///
/// Used by the plain-text note body and the note-row preview. The markdown
/// renderer uses [EmojiInlineSyntax] + [EmojiElementBuilder] instead.
List<InlineSpan> buildEmojiSpans(String text, TextStyle base) {
  if (text.isEmpty) return <InlineSpan>[TextSpan(text: text, style: base)];
  final emojiStyle = _emojiStyle(base);
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  bool? bufferIsEmoji;

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(
      text: buffer.toString(),
      style: bufferIsEmoji! ? emojiStyle : base,
    ));
    buffer.clear();
  }

  for (final cluster in text.characters) {
    final isEmoji = _clusterIsEmoji(cluster);
    if (bufferIsEmoji != null && isEmoji != bufferIsEmoji) flush();
    bufferIsEmoji = isEmoji;
    buffer.write(cluster);
  }
  flush();
  return spans;
}

// ---------------------------------------------------------------------------
// Markdown integration
// ---------------------------------------------------------------------------

/// Inline markdown syntax that captures a single emoji sequence and emits an
/// `emoji` element so [EmojiElementBuilder] can render it with an emoji font.
///
/// The pattern matches either an emoji-plane surrogate pair (a default-emoji
/// glyph such as a smiley) or any base code unit immediately followed by the
/// U+FE0F variation selector (the text-default emoji such as the warning
/// sign), each optionally extended by ZWJ joins, skin-tone modifiers, keycaps
/// and further variation selectors. Bare BMP symbols without U+FE0F are
/// intentionally not matched so ordinary text characters keep the reading
/// font. (`\u` escapes are resolved by the RegExp engine, not Dart, so they
/// are safe inside this raw string.)
class EmojiInlineSyntax extends md.InlineSyntax {
  EmojiInlineSyntax()
      : super(
          r'(?:[\uD83C-\uD83E][\uDC00-\uDFFF]|.\uFE0F)'
          r'(?:[\u200D\uFE0F\u20E3]|[\uD83C-\uD83E][\uDC00-\uDFFF])*',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('emoji', match[0]!));
    return true;
  }
}

/// Renders the `emoji` element produced by [EmojiInlineSyntax]. Returns a
/// `Text.rich` whose span flutter_markdown merges back inline with the
/// surrounding text, inheriting the parent's size/height so the emoji lines up
/// with the rest of the paragraph while drawing from an emoji font.
class EmojiElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final base = parentStyle ?? preferredStyle ?? const TextStyle();
    return Text.rich(
      TextSpan(text: element.textContent, style: _emojiStyle(base)),
    );
  }
}
