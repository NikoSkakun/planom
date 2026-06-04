import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/note.dart';
import 'package:planom/src/notes/note_controller.dart';
import 'package:planom/src/notes/note_detail_view.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late NoteController c;

  setUp(() async {
    db = freshDb();
    c = NoteController(db);
    await c.load();
  });

  // Lets real (ffi) DB futures and the editor's awaited save path drain — the
  // fake test clock never advances them on its own.
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump();
    }
  }

  Widget hostTabs(
    NoteController controller,
    Note note,
    CupertinoTabController tabController,
  ) {
    return CupertinoApp(
      home: CupertinoTabScaffold(
        controller: tabController,
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.doc), label: 'Notes'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.calendar), label: 'Other'),
          ],
        ),
        tabBuilder: (context, index) {
          if (index == 1) return const Center(child: Text('Other tab'));
          return CupertinoTabView(
            builder: (_) => NoteDetailView(
              note: note,
              controller: controller,
              isNew: true,
            ),
          );
        },
      ),
    );
  }

  testWidgets('new note keeps edits made after switching tabs and back',
      (tester) async {
    final tabController = CupertinoTabController(initialIndex: 0);
    final note = Note(title: '', content: '');
    await tester.pumpWidget(hostTabs(c, note, tabController));
    await tester.pumpAndSettle();

    // Type a title and a word of body, then drop focus (hide the keyboard) so
    // the new note is persisted.
    await tester.enterText(find.byType(CupertinoTextField).first, 'Title');
    await tester.pump();
    await tester.enterText(find.byType(CupertinoTextField).last, 'word');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    expect(c.noteById(note.id), isNotNull);
    expect(c.noteById(note.id)!.content, 'word');

    // Switch to the other tab and back (state stays alive, but the editor is
    // moved offstage and drops focus / its input connection).
    tabController.index = 1;
    await tester.pumpAndSettle();
    tabController.index = 0;
    await tester.pumpAndSettle();

    // The body is now a preview; tapping it re-opens a fresh editor.
    expect(find.byType(CupertinoTextField), findsOneWidget,
        reason: 'body should be in preview mode after the tab switch');
    await tester.tapAt(tester.getCenter(find.text('word')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsNWidgets(2));

    // Continue editing, then go back (drop focus) to persist.
    await tester.enterText(find.byType(CupertinoTextField).last, 'word more');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    expect(c.noteById(note.id)!.content, 'word more',
        reason: 'edits made after the tab switch must be persisted');
  });

  testWidgets('new-note menu button is grayed until there is text',
      (tester) async {
    final tabController = CupertinoTabController(initialIndex: 0);
    final note = Note(title: '', content: '');
    await tester.pumpWidget(hostTabs(c, note, tabController));
    await tester.pumpAndSettle();

    // The ⋯ menu button is present even on a brand-new note...
    final menu = find.byIcon(CupertinoIcons.ellipsis);
    expect(menu, findsOneWidget);

    // ...but inert while the note is empty.
    CupertinoButton button() => tester.widget<CupertinoButton>(
        find.ancestor(of: menu, matching: find.byType(CupertinoButton)));
    expect(button().onPressed, isNull,
        reason: 'menu must be disabled when the note has no text');

    // Once the user types something it becomes active.
    await tester.enterText(find.byType(CupertinoTextField).first, 'Hi');
    await tester.pump();
    expect(button().onPressed, isNotNull,
        reason: 'menu must be enabled once the note has text');
  });
}
