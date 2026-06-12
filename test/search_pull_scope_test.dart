import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/notes/note_controller.dart';
import 'package:planom/src/search/search_pull_scope.dart';
import 'package:planom/src/tasks/task_controller.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late ScrollController scroll;

  Future<void> pumpScope(WidgetTester tester) async {
    final db = freshDb();
    scroll = ScrollController();
    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: SearchPullScope(
            db: db,
            taskController: TaskController(db),
            folderController: FolderController(db),
            noteController: NoteController(db),
            eventController: EventController(db),
            child: ListView.builder(
              controller: scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(
                height: 44,
                child: Text('Row $i'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The bar strip is the ClipRect that SearchPullScope puts above the list.
  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ClipRect).first).height;

  Future<void> latchBar(WidgetTester tester) async {
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Row 5')));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(barHeight(tester), 48);
  }

  testWidgets('pull down past threshold latches the bar open',
      (tester) async {
    await pumpScope(tester);
    expect(barHeight(tester), 0);
    await latchBar(tester);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('release mid-pull continues the reveal without waiting',
      (tester) async {
    await pumpScope(tester);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Row 5')));
    // 50 px pull (≈ 32 px after touch slop ≈ 57 % reveal) — past the 30 %
    // latch threshold.
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final heightAtRelease = barHeight(tester);
    expect(heightAtRelease, greaterThan(15));
    expect(heightAtRelease, lessThan(45));
    await gesture.up();
    // Within a few ballistic frames the bar must already be growing —
    // not frozen until the bounce-back ends.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 80));
    expect(barHeight(tester), greaterThan(heightAtRelease + 4));
    await tester.pumpAndSettle();
    expect(barHeight(tester), 48);
  });

  testWidgets('upward swipe collapses the bar while the list stays pinned',
      (tester) async {
    await pumpScope(tester);
    await latchBar(tester);
    expect(scroll.position.pixels, moreOrLessEquals(0, epsilon: 1));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Row 5')));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The swipe (minus touch slop) is absorbed by the bar: it shrank
    // proportionally and the list has not scrolled underneath it.
    final h = barHeight(tester);
    expect(h, lessThan(40));
    expect(h, greaterThan(0));
    expect(scroll.position.pixels, moreOrLessEquals(0, epsilon: 1));

    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    // Bar fully dismissed; the swipe past the bar scrolls the list normally.
    expect(barHeight(tester), 0);
    expect(scroll.position.pixels, lessThan(56));
  });

  testWidgets('reversing an upward swipe grows the bar back', (tester) async {
    await pumpScope(tester);
    await latchBar(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Row 5')));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(barHeight(tester), lessThan(38));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(barHeight(tester), moreOrLessEquals(48, epsilon: 2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(barHeight(tester), 48);
    expect(scroll.position.pixels, moreOrLessEquals(0, epsilon: 1));
  });
}
