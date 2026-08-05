import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/settings/settings_controller.dart';
import 'package:planom/src/settings/settings_service.dart';
import 'package:planom/src/settings/tab_bar_config.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  group('TabBarSwipeMode', () {
    test('encodes and decodes, defaulting to pages', () {
      expect(encodeTabBarSwipeMode(TabBarSwipeMode.pages), 'pages');
      expect(encodeTabBarSwipeMode(TabBarSwipeMode.spaces), 'spaces');
      expect(decodeTabBarSwipeMode('spaces'), TabBarSwipeMode.spaces);
      expect(decodeTabBarSwipeMode('pages'), TabBarSwipeMode.pages);
      expect(decodeTabBarSwipeMode(null), TabBarSwipeMode.pages);
      expect(decodeTabBarSwipeMode('nonsense'), TabBarSwipeMode.pages);
    });

    test('persists across a reload', () async {
      final db = freshDb();
      final controller = SettingsController(SettingsService(), db);
      await controller.loadSettings();
      expect(controller.tabBarSwipeMode, TabBarSwipeMode.pages);

      await controller.updateTabBarSwipeMode(TabBarSwipeMode.spaces);
      expect(controller.tabBarSwipeMode, TabBarSwipeMode.spaces);

      final reloaded = SettingsController(SettingsService(), db);
      await reloaded.loadSettings();
      expect(reloaded.tabBarSwipeMode, TabBarSwipeMode.spaces);
    });

    test('notifies listeners when it changes', () async {
      final db = freshDb();
      final controller = SettingsController(SettingsService(), db);
      await controller.loadSettings();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.updateTabBarSwipeMode(TabBarSwipeMode.spaces);
      expect(notifications, 1);
      // Setting the same value again is a no-op.
      await controller.updateTabBarSwipeMode(TabBarSwipeMode.spaces);
      expect(notifications, 1);
    });
  });

  group('tab layout with the newer built-ins', () {
    test('the default layout carries every built-in tab, Settings last', () {
      final page = TabBarConfig.defaultLayout().pages.single;
      final indices = page.map((it) => it.builtinIndex).toList();
      expect(indices.toSet(), {0, 1, 2, 3, 4, 5, 6});
      expect(indices.last, 4, reason: 'Settings sits at the end');
      expect(page.length, lessThanOrEqualTo(TabBarConfig.maxItemsPerPage));
    });

    test('a legacy five-tab order gains Finance and Goals before Settings',
        () {
      final config = TabBarConfig.fromLegacy(
        tabVisibility: const {0: true, 1: true, 2: true, 3: true, 4: true},
        tabOrder: const [0, 1, 2, 3, 4],
      );
      final indices =
          config.pages.single.map((it) => it.builtinIndex).toList();
      expect(indices, [0, 1, 2, 3, 5, 6, 4]);
    });

    test('a legacy layout with tabs hidden keeps them hidden', () {
      final config = TabBarConfig.fromLegacy(
        tabVisibility: const {0: true, 1: false, 2: true, 3: false, 4: true},
        tabOrder: const [0, 1, 2, 3, 4],
      );
      final indices =
          config.pages.single.map((it) => it.builtinIndex).toList();
      expect(indices, [0, 2, 5, 6, 4]);
    });

    test('a builtinIndex outside the known range is dropped on parse', () {
      expect(
        TabItem.fromJson(const {'kind': 'builtin', 'builtinIndex': 6}),
        isNotNull,
      );
      expect(
        TabItem.fromJson(const {'kind': 'builtin', 'builtinIndex': 7}),
        isNull,
      );
    });
  });

  group('newly shipped built-in tabs', () {
    /// Saves [config] as the user's layout, then loads a fresh controller the
    /// way app start-up would.
    Future<SettingsController> reload(DatabaseService db) async {
      final controller = SettingsController(SettingsService(), db);
      await controller.loadSettings();
      return controller;
    }

    test('a layout saved before Finance/Goals existed gains them once',
        () async {
      final db = freshDb();
      // A five-tab layout, as an older build would have persisted it.
      await db.setAppSetting(
        'tab_bar_config',
        TabBarConfig(pages: [
          [
            TabItem.builtin(0),
            TabItem.builtin(1),
            TabItem.builtin(2),
            TabItem.builtin(3),
            TabItem.builtin(4),
          ]
        ]).toJsonString(),
      );

      final first = await reload(db);
      final indices =
          first.tabBarConfig.pages.first.map((it) => it.builtinIndex).toList();
      expect(indices, [0, 1, 2, 3, 5, 6, 4],
          reason: 'new tabs land in front of Settings');

      // Removing one afterwards must stick — the migration runs once.
      await first.updateTabBarConfig(
          first.tabBarConfig.removeItem(0, indices.indexOf(6)));
      final second = await reload(db);
      expect(
        second.tabBarConfig.flattened.map((it) => it.builtinIndex),
        isNot(contains(6)),
      );
    });

    test('a tab the user had already removed is not resurrected', () async {
      final db = freshDb();
      // Notes (1) deliberately absent, and the layout already knows about
      // every built-in that shipped at the time.
      await db.setAppSetting(
        'tab_bar_config',
        TabBarConfig(pages: [
          [TabItem.builtin(0), TabItem.builtin(2), TabItem.builtin(4)]
        ]).toJsonString(),
      );

      final controller = await reload(db);
      final indices = controller.tabBarConfig.flattened
          .map((it) => it.builtinIndex)
          .toList();
      expect(indices, isNot(contains(1)), reason: 'Notes stays removed');
      expect(indices, containsAll([5, 6]));
    });

    test('a fresh install needs no migration', () async {
      final db = freshDb();
      final controller = await reload(db);
      expect(
        controller.tabBarConfig.flattened.map((it) => it.builtinIndex).toSet(),
        {0, 1, 2, 3, 4, 5, 6},
      );
    });
  });
}
