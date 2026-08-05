import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:planom/src/notes/markdown_math.dart';
import 'package:planom/src/notes/markdown_view.dart';

/// Parses [source] the way MarkdownView does — the gitHubWeb extension set
/// plus the math syntaxes — and returns the flattened element tags in order.
List<String> _tags(String source) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubWeb,
    inlineSyntaxes: mathInlineSyntaxes(),
    encodeHtml: false,
  );
  final found = <String>[];
  void walk(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is md.Element) {
        found.add(node.tag);
        final children = node.children;
        if (children != null) walk(children);
      }
    }
  }

  walk(document.parseLines(source.split('\n')));
  return found;
}

/// The TeX captured for the first element with [tag], or null.
String? _texOf(String source, String tag) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubWeb,
    inlineSyntaxes: mathInlineSyntaxes(),
    encodeHtml: false,
  );
  String? found;
  void walk(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is md.Element) {
        if (node.tag == tag && found == null) found = node.textContent;
        final children = node.children;
        if (children != null) walk(children);
      }
    }
  }

  walk(document.parseLines(source.split('\n')));
  return found;
}

/// Spacer paragraphs inserted by [preserveMarkdownBlankLines] — a lone
/// no-break space on its own line.
int _spacerCount(String rendered) =>
    rendered.split('\n').where((l) => l == '\u00A0').length;

void main() {
  group('inline math', () {
    test(r'$…$ becomes a math element', () {
      expect(_tags(r'Euler wrote $e^{i\pi}+1=0$ here.'), contains(kMathTag));
      expect(_texOf(r'x is $a^2+b^2$ ok', kMathTag), r'a^2+b^2');
    });

    test(r'\(…\) is accepted too', () {
      expect(_texOf(r'inline \(x_1\) here', kMathTag), 'x_1');
    });

    test('prices are left alone', () {
      // The opener refuses a following digit and the closer refuses a
      // preceding space / following digit, which is what keeps prose prose.
      for (final prose in <String>[
        r'It cost $5 and $7 total.',
        r'Budget: $50-$80 per night.',
        r'US$5 and CA$7',
        r'price $5, tip $2',
        r'$5/$10',
      ]) {
        expect(_tags(prose), isNot(contains(kMathTag)), reason: prose);
      }
    });

    test('an inline code span is never swallowed', () {
      final tags = _tags(r'Use `$a` $b `c$` d');
      expect(tags, isNot(contains(kMathTag)));
      expect(tags.where((t) => t == 'code').length, 2);
    });

    test(r'an escaped \$ does not open math', () {
      expect(_tags(r'a\$b and \$c'), isNot(contains(kMathTag)));
    });

    test('an unclosed delimiter stays text', () {
      expect(_tags(r'unclosed $x here'), isNot(contains(kMathTag)));
    });

    test('an empty delimiter pair is not math', () {
      expect(_tags(r'empty $$ here'), isNot(contains(kMathTag)));
    });
  });

  group('display math', () {
    test(r'$$…$$ becomes a display element, even across lines', () {
      expect(
        _tags('Before\n\n\$\$\n\\int_0^1 x^2\\,dx\n\$\$\n\nAfter'),
        contains(kDisplayMathTag),
      );
      expect(
        _texOf('\$\$\n\\frac{a}{b}\n\$\$', kDisplayMathTag),
        r'\frac{a}{b}',
      );
    });

    test(r'\[…\] is accepted too', () {
      expect(_texOf(r'\[ x = y \]', kDisplayMathTag), 'x = y');
    });

    test(r'$$ wins over $ so a display block is never read as two inlines', () {
      final tags = _tags(r'$$a+b$$');
      expect(tags, contains(kDisplayMathTag));
      expect(tags, isNot(contains(kMathTag)));
    });
  });

  group('markdown extensions stay available', () {
    test('GFM tables parse', () {
      expect(_tags('| a | b |\n| --- | --- |\n| 1 | 2 |'), contains('table'));
    });

    test('task lists parse', () {
      expect(_tags('- [x] done\n- [ ] todo'), contains('input'));
    });

    test('strikethrough parses', () {
      expect(_tags('~~gone~~'), contains('del'));
    });

    test('fenced code is left verbatim, math inside it is not parsed', () {
      final tags = _tags('```\n\$x^2\$\n```');
      expect(tags, contains('code'));
      expect(tags, isNot(contains(kMathTag)));
    });
  });

  group('blank-line preservation', () {
    test('a run of blank lines keeps its vertical gap', () {
      final out = preserveMarkdownBlankLines('a\n\n\n\nb');
      // Each extra blank line becomes a no-break-space paragraph so the gap
      // survives markdown's collapsing.
      expect(_spacerCount(out), 2);
    });

    test('a fenced code block is passed through untouched', () {
      const source = '```\ncode\n\n\nstill code\n```';
      expect(preserveMarkdownBlankLines(source), source);
    });

    test('a display-math block is passed through untouched', () {
      const source = '\$\$\n\\begin{aligned}\n\n x &= y\n\\end{aligned}\n\$\$';
      expect(preserveMarkdownBlankLines(source), source);
    });

    test(r'\[ … \] delimiters open and close a math block too', () {
      const source = '\\[\na\n\n\nb\n\\]';
      expect(preserveMarkdownBlankLines(source), source);
    });

    test('an inline \$\$x\$\$ on one line does not open a block', () {
      // Not a lone delimiter line, so the tracker stays closed and the blank
      // run after it is still expanded.
      final out = preserveMarkdownBlankLines('\$\$x\$\$\n\n\n\nafter');
      expect(_spacerCount(out), 2);
    });

    test('a stray lone \$\$ does not protect the rest of the note', () {
      // The opening delimiter here shares a line with text, so the later lone
      // '\$\$' has no partner — pairing keeps it from swallowing everything
      // after it, which would silently drop the note's blank-line spacing.
      final out = preserveMarkdownBlankLines(
          'Formula: \$\$\na\n\$\$\n\nnext\n\n\n\ntail');
      expect(_spacerCount(out), 2);
    });

    test('a math fence inside a code block does not toggle math mode', () {
      const source = '```\n\$\$\n\n\nnot math\n```\n\n\n\nafter';
      final out = preserveMarkdownBlankLines(source);
      expect(out.startsWith('```\n\$\$\n\n\nnot math\n```'), isTrue);
      expect(_spacerCount(out), 2,
          reason: 'blank lines after the fence are still expanded');
    });
  });
}
