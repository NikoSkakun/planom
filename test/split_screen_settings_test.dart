import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/settings/settings_controller.dart';
import 'package:planom/src/settings/settings_service.dart';

import 'support/test_db.dart';

/// Covers the Split Screen toggle invariants in [SettingsController]:
/// all three default on; turning both entry methods off forces the feature
/// off; re-enabling the feature with both entry methods off re-enables them;
/// and the derived `*Available` getters gate on the master switch.
void main() {
  initTestDatabaseFactory();

  Future<SettingsController> freshSettings() async {
    final c = SettingsController(SettingsService(), freshDb());
    await c.loadSettings();
    return c;
  }

  test('defaults: feature + both entry methods on', () async {
    final c = await freshSettings();
    expect(c.splitScreenEnabled, isTrue);
    expect(c.splitScreenFromMenu, isTrue);
    expect(c.splitScreenFromDrag, isTrue);
    expect(c.splitScreenMenuAvailable, isTrue);
    expect(c.splitScreenDragAvailable, isTrue);
  });

  test('disabling the feature gates both availability getters', () async {
    final c = await freshSettings();
    await c.updateSplitScreenEnabled(false);
    expect(c.splitScreenEnabled, isFalse);
    // Entry-method flags retain their value but availability is gated off.
    expect(c.splitScreenFromMenu, isTrue);
    expect(c.splitScreenMenuAvailable, isFalse);
    expect(c.splitScreenDragAvailable, isFalse);
  });

  test('turning both entry methods off forces the feature off', () async {
    final c = await freshSettings();
    await c.updateSplitScreenFromMenu(false);
    expect(c.splitScreenEnabled, isTrue); // still reachable via drag
    await c.updateSplitScreenFromDrag(false);
    expect(c.splitScreenEnabled, isFalse); // now unreachable → off
  });

  test('re-enabling the feature with both entry methods off restores them',
      () async {
    final c = await freshSettings();
    await c.updateSplitScreenFromMenu(false);
    await c.updateSplitScreenFromDrag(false);
    expect(c.splitScreenEnabled, isFalse);

    await c.updateSplitScreenEnabled(true);
    expect(c.splitScreenEnabled, isTrue);
    expect(c.splitScreenFromMenu, isTrue);
    expect(c.splitScreenFromDrag, isTrue);
  });

  test('settings persist across a reload on the same DB', () async {
    final service = SettingsService();
    final db = freshDb();
    final c = SettingsController(service, db);
    await c.loadSettings();
    await c.updateSplitScreenFromDrag(false);
    expect(c.splitScreenFromDrag, isFalse);

    final c2 = SettingsController(service, db);
    await c2.loadSettings();
    expect(c2.splitScreenFromDrag, isFalse);
    expect(c2.splitScreenEnabled, isTrue); // menu still on → reachable
  });
}
