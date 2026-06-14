import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/theme/app_theme.dart';

/// Locks in the dark-mode theme tokens introduced to stop menus / headers /
/// circle buttons rendering as pure black (or invisible) against the app's
/// dark-gray scaffold.
void main() {
  // Resolves the tokens inside a single pump for [b] — contexts must not be
  // reused across pumps (a stale context resolves to the light fallback).
  Future<Map<String, Object?>> resolve(
      WidgetTester tester, Brightness b) async {
    late Map<String, Object?> out;
    await tester.pumpWidget(CupertinoApp(
      theme: CupertinoThemeData(brightness: b),
      home: Builder(builder: (c) {
        final deco = AppColors.menuDecoration(c);
        out = {
          'surface': AppColors.surface.resolveFrom(c).value,
          'shadowAlpha': AppColors.menuShadow.resolveFrom(c).alpha,
          'menuColor': deco.color!.value,
          'hasBorder': deco.border != null,
          'hasShadow': deco.boxShadow!.isNotEmpty,
          'circle': AppColors.circleButtonBackground.resolveFrom(c).value,
        };
        return const SizedBox();
      }),
    ));
    return out;
  }

  testWidgets('surface + menu fill match the scaffold tone, never pure black',
      (tester) async {
    final dark = await resolve(tester, Brightness.dark);
    expect(dark['surface'], 0xFF1C1C1E);
    expect(dark['menuColor'], 0xFF1C1C1E);
    expect(dark['menuColor'], isNot(0xFF000000));

    final light = await resolve(tester, Brightness.light);
    expect(light['surface'], 0xFFFFFFFF);
    expect(light['menuColor'], 0xFFFFFFFF);
  });

  testWidgets('menu has a hairline border + shadow, heavier shadow in dark',
      (tester) async {
    final dark = await resolve(tester, Brightness.dark);
    expect(dark['hasBorder'], isTrue,
        reason: 'hairline edge delineates the menu in dark');
    expect(dark['hasShadow'], isTrue);

    final light = await resolve(tester, Brightness.light);
    expect((dark['shadowAlpha']! as int), greaterThan(light['shadowAlpha']! as int),
        reason: 'shadow is stronger in dark to read over the dark scaffold');
  });

  testWidgets('circle-button fill is visibly lighter than the dark scaffold',
      (tester) async {
    final dark = await resolve(tester, Brightness.dark);
    // 0xFF1C1C1E is the dark scaffold; the fill must be lighter so the
    // circle is visible.
    expect(dark['circle'], isNot(0xFF1C1C1E));
    expect((dark['circle']! as int) & 0xFF, greaterThan(0x1C));
  });
}
