import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/settings/settings_controller.dart';
import 'package:planom/src/settings/settings_service.dart';
import 'package:planom/src/settings/tab_bar_config.dart';
import 'package:planom/src/spaces/space.dart';

import 'support/test_db.dart';

/// Tab bar layouts are per space: one space can show Tasks and Notes while
/// another shows Finance and Goals.
void main() {
  initTestDatabaseFactory();

  TabBarConfig singlePage(List<int> builtins) => TabBarConfig(pages: [
        [for (final i in builtins) TabItem.builtin(i)],
      ]);

  List<int> builtinsOf(TabBarConfig config) => [
        for (final item in config.flattened)
          if (item.kind == TabKind.builtin && item.builtinIndex != null)
            item.builtinIndex!,
      ];

  Future<SettingsController> load(DatabaseService db) async {
    final controller = SettingsController(SettingsService(), db);
    await controller.loadSettings();
    return controller;
  }

  test('a space with no layout of its own follows the default space', () async {
    final db = freshDb();
    final settings = await load(db);

    await settings.updateTabBarConfig(singlePage([0, 1]));
    settings.setActiveSpace('work');

    // Not yet edited: it borrows rather than resetting to the stock layout, so
    // adding a space does not silently change what the bar looks like.
    expect(settings.hasOwnTabBarConfig('work'), isFalse);
    expect(builtinsOf(settings.tabBarConfig), [0, 1]);
  });

  test('editing one space leaves the others alone', () async {
    final db = freshDb();
    final settings = await load(db);

    await settings.updateTabBarConfig(singlePage([0, 1]));
    settings.setActiveSpace('work');
    await settings.updateTabBarConfig(singlePage([5, 6, 4]));

    expect(builtinsOf(settings.tabBarConfig), [5, 6, 4]);
    settings.setActiveSpace(kDefaultSpaceId);
    expect(builtinsOf(settings.tabBarConfig), [0, 1]);
  });

  test('layouts survive a reload, keyed by space', () async {
    final db = freshDb();
    final first = await load(db);
    await first.updateTabBarConfig(singlePage([0, 1]));
    first.setActiveSpace('work');
    await first.updateTabBarConfig(singlePage([5, 6]));

    final second = await load(db);
    expect(builtinsOf(second.tabBarConfig), [0, 1], reason: 'default space');
    second.setActiveSpace('work');
    expect(builtinsOf(second.tabBarConfig), [5, 6]);
  });

  test('the default space keeps the original storage key', () async {
    final db = freshDb();
    final settings = await load(db);
    await settings.updateTabBarConfig(singlePage([0, 2]));

    final rows = await db.getAppSettings();
    final keys = rows.map((r) => r['key']).toList();
    // An existing install's layout lives under `tab_bar_config`; moving it
    // would strand every layout saved before this change.
    expect(keys, contains('tab_bar_config'));
    expect(keys.where((k) => k.toString().startsWith('tab_bar_config:')),
        isEmpty);
  });

  test('a space can be handed back to the default layout', () async {
    final db = freshDb();
    final settings = await load(db);
    await settings.updateTabBarConfig(singlePage([0, 1]));
    settings.setActiveSpace('work');
    await settings.updateTabBarConfig(singlePage([5]));
    expect(settings.hasOwnTabBarConfig('work'), isTrue);

    await settings.resetTabBarConfig('work');
    expect(settings.hasOwnTabBarConfig('work'), isFalse);
    expect(builtinsOf(settings.tabBarConfig), [0, 1]);

    // And it stays gone across a reload.
    final reloaded = await load(db);
    reloaded.setActiveSpace('work');
    expect(reloaded.hasOwnTabBarConfig('work'), isFalse);
  });

  test('the default space cannot be reset — it is the fallback', () async {
    final db = freshDb();
    final settings = await load(db);
    await settings.updateTabBarConfig(singlePage([0, 1]));
    await settings.resetTabBarConfig(kDefaultSpaceId);
    expect(builtinsOf(settings.tabBarConfig), [0, 1]);
  });

  test('deleting a space forgets its layout', () async {
    final db = freshDb();
    final settings = await load(db);
    settings.setActiveSpace('work');
    await settings.updateTabBarConfig(singlePage([5, 6]));

    await settings.forgetSpaceSettings('work');
    final rows = await db.getAppSettings();
    expect(rows.map((r) => r['key']), isNot(contains('tab_bar_config:work')));

    // A later space reusing the id starts from the default space's layout.
    final reloaded = await load(db);
    reloaded.setActiveSpace('work');
    expect(reloaded.hasOwnTabBarConfig('work'), isFalse);
  });

  test('a newly shipped tab is surfaced in every space, not just the open one',
      () async {
    final db = freshDb();
    final settings = await load(db);
    // Two spaces whose layouts predate the Goals tab (6), and a "known" set
    // that says so.
    await settings.updateTabBarConfig(singlePage([0, 1, 4]));
    settings.setActiveSpace('work');
    await settings.updateTabBarConfig(singlePage([0, 5, 4]));
    await db.setAppSetting('tab_bar_known_builtins', '0,1,2,3,4,5');

    final reloaded = await load(db);
    expect(builtinsOf(reloaded.tabBarConfig), contains(6),
        reason: 'default space gets the new tab');
    reloaded.setActiveSpace('work');
    expect(builtinsOf(reloaded.tabBarConfig), contains(6),
        reason: 'a space that was not open still gets it');
  });
}
