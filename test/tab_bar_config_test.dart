import 'package:flutter_test/flutter_test.dart';
import 'package:planom/src/settings/tab_bar_config.dart';

void main() {
  group('TabBarConfig.reorderItem', () {
    TabBarConfig single(List<TabItem> items) => TabBarConfig(pages: [items]);

    List<int> builtins(TabBarConfig cfg, int page) =>
        cfg.pages[page].map((it) => it.builtinIndex!).toList();

    test('moves an item earlier in the page', () {
      final cfg = single([
        TabItem.builtin(0),
        TabItem.builtin(1),
        TabItem.builtin(2),
      ]);
      // Move index 2 to the front (newIndex already adjusted by caller).
      final next = cfg.reorderItem(0, 2, 0);
      expect(builtins(next, 0), [2, 0, 1]);
    });

    test('moves an item later in the page', () {
      final cfg = single([
        TabItem.builtin(0),
        TabItem.builtin(1),
        TabItem.builtin(2),
      ]);
      // Move index 0 to the end. After removal the list is [1,2]; inserting at
      // index 2 (already decremented by the editor) appends.
      final next = cfg.reorderItem(0, 0, 2);
      expect(builtins(next, 0), [1, 2, 0]);
    });

    test('only touches the targeted page', () {
      final cfg = TabBarConfig(pages: [
        [TabItem.builtin(0), TabItem.builtin(1)],
        [TabItem.builtin(2), TabItem.builtin(3)],
      ]);
      final next = cfg.reorderItem(1, 1, 0);
      expect(builtins(next, 0), [0, 1]);
      expect(builtins(next, 1), [3, 2]);
    });

    test('clamps an out-of-range destination instead of throwing', () {
      final cfg = single([TabItem.builtin(0), TabItem.builtin(1)]);
      final next = cfg.reorderItem(0, 0, 99);
      expect(builtins(next, 0), [1, 0]);
    });

    test('ignores an invalid page or item index', () {
      final cfg = single([TabItem.builtin(0)]);
      expect(builtins(cfg.reorderItem(5, 0, 0), 0), [0]);
      expect(builtins(cfg.reorderItem(0, 9, 0), 0), [0]);
    });

    test('survives a JSON round-trip after reordering', () {
      final cfg = single([
        TabItem.builtin(0),
        TabItem.shortcut(shortcutTarget: ShortcutTarget.smartToday),
      ]).reorderItem(0, 1, 0);
      final parsed = TabBarConfig.tryParse(cfg.toJsonString())!;
      expect(parsed.pages[0][0].kind, TabKind.shortcut);
      expect(parsed.pages[0][0].shortcutTarget, ShortcutTarget.smartToday);
      expect(parsed.pages[0][1].builtinIndex, 0);
    });
  });
}
