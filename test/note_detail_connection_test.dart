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

  // Lets the real (ffi) DB futures and the editor's awaited save path drain —
  // the fake test clock never advances them on its own.
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump();
    }
  }

  // Regression test for the real "lost edits after a tab switch" cause: the
  // new-note placeholder is built inside the route's builder closure, so a
  // route rebuild (the offstage→onstage flip on a tab switch) mints a fresh
  // Note with a NEW id and hands it to the same editor State. The editor must
  // keep persisting against the id it was first opened with — otherwise saves
  // after the rebuild target a never-inserted row and are silently dropped.
  testWidgets(
      'edits survive widget.note being replaced by a new placeholder on rebuild',
      (tester) async {
    final rebuild = ValueNotifier<int>(0);
    final placeholderIds = <String>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, __) {
            // Mimics the route builder closure: a fresh placeholder (new id)
            // every time this rebuilds.
            final draft = Note(title: '', content: '');
            placeholderIds.add(draft.id);
            return NoteDetailView(note: draft, controller: c, isNew: true);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type a first word into the body and drop focus (persists the new note).
    await tester.enterText(find.byType(CupertinoTextField).last, 'aaaaa');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    // The note was created under the FIRST placeholder id.
    expect(c.noteById(placeholderIds.first)?.content, 'aaaaa');
    expect(c.allNotes.length, 1);

    // Force a rebuild: the builder mints a NEW placeholder (different id) and
    // hands it to the SAME NoteDetailView State (no key) — exactly what a route
    // rebuild after a tab switch does.
    rebuild.value++;
    await tester.pumpAndSettle();
    expect(placeholderIds.length, greaterThan(1));
    expect(placeholderIds.last, isNot(placeholderIds.first));

    // The body is now a preview ('aaaaa'); tapping it re-opens the editor.
    await tester.tapAt(tester.getCenter(find.text('aaaaa')));
    await tester.pumpAndSettle();

    // Continue editing, then drop focus to persist.
    await tester.enterText(find.byType(CupertinoTextField).last, 'aaaaabbbbbb');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await drain(tester);

    // The edit must land on the ORIGINAL note, not the throwaway rebuild id.
    expect(c.noteById(placeholderIds.first)?.content, 'aaaaabbbbbb',
        reason: 'saves must stay aimed at the originally-created note id');
    expect(c.noteById(placeholderIds.last), isNull,
        reason: 'the rebuild placeholder id must never be persisted');
    expect(c.allNotes.length, 1,
        reason: 'no duplicate/orphan note should be created on rebuild');
  });
}
