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

  // Fires the editor's 1s autosave debounce, then lets the real (ffi) DB
  // futures drain (runAsync, since the fake clock won't advance them).
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump();
    }
  }

  // Mirrors HomeShell._WideLayout: an IndexedStack of CupertinoTabViews — the
  // iPad / desktop sidebar layout. [wrapTickerMode] reflects the fix: the real
  // _WideLayout now wraps each child in TickerMode(enabled: active) so hidden
  // tabs can tell they've been hidden (CupertinoTabScaffold does this for free;
  // a bare IndexedStack does not).
  Widget hostIndexedStack(
    NoteController controller,
    Note note,
    ValueNotifier<int> index, {
    required bool wrapTickerMode,
  }) {
    return CupertinoApp(
      home: ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (context, i, _) {
          Widget tab(int childIndex, Widget child) {
            if (!wrapTickerMode) return child;
            return TickerMode(enabled: childIndex == i, child: child);
          }

          return Column(
            children: [
              CupertinoButton(
                onPressed: () => index.value = i == 0 ? 1 : 0,
                child: const Text('switch'),
              ),
              Expanded(
                child: IndexedStack(
                  index: i,
                  children: [
                    tab(
                      0,
                      CupertinoTabView(
                        builder: (_) => NoteDetailView(
                          note: note,
                          controller: controller,
                          isNew: true,
                        ),
                      ),
                    ),
                    tab(1, const Center(child: Text('Other tab'))),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  testWidgets(
      'sidebar layout WITHOUT TickerMode keeps the editor stuck in edit mode '
      'after a tab switch (the bug)', (tester) async {
    final index = ValueNotifier<int>(0);
    final note = Note(title: 'T', content: 'aaaaa');
    await tester.pumpWidget(
        hostIndexedStack(c, note, index, wrapTickerMode: false));
    await tester.pumpAndSettle();

    // Focus the body so the editor is actively editing (2 fields: title+body).
    await tester.tap(find.byType(CupertinoTextField).last);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsNWidgets(2));

    // Switch away and back via the IndexedStack index.
    index.value = 1;
    await tester.pumpAndSettle();
    index.value = 0;
    await tester.pumpAndSettle();

    // Without the TickerMode signal the editor never learned it was hidden, so
    // the focused body field is still mounted — its IME connection is now the
    // stale one that drops characters on a real device.
    expect(find.byType(CupertinoTextField), findsNWidgets(2),
        reason: 'reproduces the bug: editor stays in edit mode when hidden');
  });

  testWidgets(
      'sidebar layout WITH TickerMode returns to preview after a tab switch '
      'and keeps edits made on return (the fix)', (tester) async {
    final index = ValueNotifier<int>(0);
    final note = Note(title: '', content: '');
    await tester.pumpWidget(
        hostIndexedStack(c, note, index, wrapTickerMode: true));
    await tester.pumpAndSettle();

    // Title autofocuses on a new note; type through the real IME connection.
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.enterText('Title');
    await tester.pump();

    await tester.tap(find.byType(CupertinoTextField).last);
    await tester.pump();
    tester.testTextInput.enterText('aaaaa');
    await tester.pump();

    // Hide the keyboard WITHOUT unfocusing (iOS hide-keyboard key leaves the
    // field focused).
    tester.testTextInput.hide();
    await tester.pump();
    await drain(tester);
    expect(c.noteById(note.id)?.content, 'aaaaa');

    // Switch away and back.
    index.value = 1;
    await tester.pumpAndSettle();
    index.value = 0;
    await tester.pumpAndSettle();
    await drain(tester);

    // The fix: the hidden editor dropped focus + returned to preview, so the
    // body is now a single preview (only the title field remains editable).
    expect(find.byType(CupertinoTextField), findsOneWidget,
        reason: 'editor must return to preview mode after being hidden');

    // Continue editing: tapping the preview rebuilds a fresh field/connection.
    final bodyText = find.text('aaaaa');
    expect(bodyText, findsOneWidget);
    await tester.tapAt(tester.getCenter(bodyText));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsNWidgets(2));
    expect(tester.testTextInput.hasAnyClients, isTrue,
        reason: 'a fresh input connection must be open after re-tapping');

    tester.testTextInput.enterText('aaaaabbbbbb');
    await tester.pump();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    expect(c.noteById(note.id)?.content, 'aaaaabbbbbb',
        reason: 'characters typed after the tab switch must be saved');
  });

  testWidgets(
      'tab-scaffold layout: edits typed after a tab switch are kept',
      (tester) async {
    final tabController = CupertinoTabController(initialIndex: 0);
    final note = Note(title: '', content: '');
    await tester.pumpWidget(
      CupertinoApp(
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
          tabBuilder: (context, idx) {
            if (idx == 1) return const Center(child: Text('Other tab'));
            return CupertinoTabView(
              builder: (_) => NoteDetailView(
                note: note,
                controller: c,
                isNew: true,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.testTextInput.enterText('Title');
    await tester.pump();
    await tester.tap(find.byType(CupertinoTextField).last);
    await tester.pump();
    tester.testTextInput.enterText('aaaaa');
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump();
    await drain(tester);
    expect(c.noteById(note.id)?.content, 'aaaaa');

    tabController.index = 1;
    await tester.pumpAndSettle();
    tabController.index = 0;
    await tester.pumpAndSettle();
    await drain(tester);

    expect(find.byType(CupertinoTextField), findsOneWidget,
        reason: 'editor must return to preview mode after being hidden');
    final bodyText = find.text('aaaaa');
    await tester.tapAt(tester.getCenter(bodyText));
    await tester.pumpAndSettle();

    tester.testTextInput.enterText('aaaaabbbbbb');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    expect(c.noteById(note.id)?.content, 'aaaaabbbbbb',
        reason: 'characters typed after the tab switch must be saved');
  });
}
