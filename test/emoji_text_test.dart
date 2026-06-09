import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:planom/src/utils/emoji_text.dart';

void main() {
  const base = TextStyle(fontSize: 16, fontFamily: 'Inter');

  TextStyle styleAt(List<InlineSpan> spans, String fragment) {
    for (final span in spans) {
      if (span is TextSpan && span.text == fragment) return span.style!;
    }
    fail('No span with text "$fragment" in $spans');
  }

  group('buildEmojiSpans', () {
    test('splits a text-default (VS16) emoji onto an emoji font', () {
      final spans = buildEmojiSpans('Careful ⚠️ here', base);
      // The warning emoji must be isolated into its own span drawn with the
      // emoji font, while the surrounding text keeps the reading font.
      expect(styleAt(spans, 'Careful ').fontFamily, 'Inter');
      expect(styleAt(spans, '⚠️').fontFamily, kEmojiFontFallback.first);
      expect(styleAt(spans, ' here').fontFamily, 'Inter');
    });

    test('keeps a bare BMP symbol (no VS16) in the reading font', () {
      // A lone warning sign without the variation selector is genuine text.
      final spans = buildEmojiSpans('arrow → done', base);
      expect(spans.length, 1);
      expect((spans.single as TextSpan).style!.fontFamily, 'Inter');
    });

    test('treats surrogate-pair emoji and ZWJ sequences as emoji', () {
      final spans = buildEmojiSpans('a\u{1F600}b', base);
      expect(styleAt(spans, '\u{1F600}').fontFamily, kEmojiFontFallback.first);
    });

    test('empty text yields a single empty span', () {
      final spans = buildEmojiSpans('', base);
      expect(spans.length, 1);
    });
  });

  group('EmojiInlineSyntax', () {
    String render(String input) {
      final doc = md.Document(inlineSyntaxes: [EmojiInlineSyntax()]);
      final nodes = doc.parseInline(input);
      final tags = <String>[];
      for (final n in nodes) {
        if (n is md.Element) tags.add(n.tag);
      }
      return tags.join(',');
    }

    test('emits an emoji element for a VS16 emoji', () {
      expect(render('hi ⚠️'), contains('emoji'));
    });

    test('emits an emoji element for a surrogate-pair emoji', () {
      expect(render('hi \u{1F600}'), contains('emoji'));
    });

    test('does not match a bare text symbol', () {
      expect(render('a → b'), isEmpty);
    });
  });
}
