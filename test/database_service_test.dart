import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/app_folder.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/models/contact.dart';
import 'package:planom/src/models/event.dart';
import 'package:planom/src/models/list_section.dart';
import 'package:planom/src/models/note.dart';
import 'package:planom/src/models/note_folder.dart';
import 'package:planom/src/models/routine.dart';
import 'package:planom/src/models/routine_entry.dart';
import 'package:planom/src/models/tag.dart';
import 'package:planom/src/models/task.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;

  setUp(() {
    db = freshDb();
  });

  tearDown(() async {
    await db.resetUserData();
    await db.close();
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  Task makeTask({
    required String id,
    String title = 'Task',
    String? note,
    int sortOrder = 0,
    DateTime? creationDate,
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      creationDate: creationDate ?? DateTime.now(),
      iconId: 'circle',
      title: title,
      note: note,
      isCompleted: isCompleted,
      sortOrder: sortOrder,
    );
  }

  Note makeNote({
    required String id,
    String title = 'Note',
    String content = '',
    int sortOrder = 0,
    DateTime? modified,
  }) {
    final now = DateTime.now();
    return Note(
      id: id,
      title: title,
      content: content,
      creationDate: now,
      modifiedDate: modified ?? now,
      sortOrder: sortOrder,
    );
  }

  Event makeEvent({
    required String id,
    String title = 'Event',
    String? note,
    required DateTime date,
  }) {
    return Event(
      id: id,
      creationDate: DateTime.now(),
      iconId: 'calendar',
      title: title,
      note: note,
      date: date,
    );
  }

  // ── Tasks ───────────────────────────────────────────────────────────────────

  group('tasks', () {
    test('insert + getTasks returns active rows only', () async {
      await db.insertTask(makeTask(id: 't1', title: 'One'));
      final tasks = await db.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.id, 't1');
      expect(tasks.first.title, 'One');
    });

    test('getTasks ordering: sortOrder ASC then creationDate DESC', () async {
      final base = DateTime(2024, 1, 1, 12);
      // Two with sortOrder 0 — newest creationDate first.
      await db.insertTask(makeTask(
          id: 'older', sortOrder: 0, creationDate: base));
      await db.insertTask(makeTask(
          id: 'newer',
          sortOrder: 0,
          creationDate: base.add(const Duration(hours: 1))));
      // One with a higher sortOrder — comes last.
      await db.insertTask(makeTask(
          id: 'sorted',
          sortOrder: 5,
          creationDate: base.add(const Duration(hours: 2))));

      final ids = (await db.getTasks()).map((t) => t.id).toList();
      expect(ids, ['newer', 'older', 'sorted']);
    });

    test('updateTask persists changes', () async {
      await db.insertTask(makeTask(id: 't1', title: 'Before'));
      final t = (await db.getTasks()).first;
      await db.updateTask(t.copyWith(title: 'After'));
      final updated = (await db.getTasks()).first;
      expect(updated.title, 'After');
    });

    test('softDeleteTask moves row to trash', () async {
      await db.insertTask(makeTask(id: 't1'));
      await db.softDeleteTask('t1', DateTime.now());

      expect(await db.getTasks(), isEmpty);
      final trashed = await db.getTrashedTasks();
      expect(trashed.length, 1);
      expect(trashed.first.id, 't1');
      expect(trashed.first.isDeleted, isTrue);
    });

    test('restoreTask brings row back', () async {
      await db.insertTask(makeTask(id: 't1'));
      await db.softDeleteTask('t1', DateTime.now());
      await db.restoreTask('t1');

      expect(await db.getTrashedTasks(), isEmpty);
      final active = await db.getTasks();
      expect(active.length, 1);
      expect(active.first.isDeleted, isFalse);
    });

    test('permanentlyDeleteTask removes the row entirely', () async {
      await db.insertTask(makeTask(id: 't1'));
      await db.softDeleteTask('t1', DateTime.now());
      await db.permanentlyDeleteTask('t1');

      expect(await db.getTasks(), isEmpty);
      expect(await db.getTrashedTasks(), isEmpty);
    });

    test('clearTrashedTasks empties only trashed rows', () async {
      await db.insertTask(makeTask(id: 'active'));
      await db.insertTask(makeTask(id: 'gone'));
      await db.softDeleteTask('gone', DateTime.now());

      await db.clearTrashedTasks();

      expect(await db.getTrashedTasks(), isEmpty);
      expect((await db.getTasks()).single.id, 'active');
    });

    test('softDeleteTasksForList trashes only that list\'s tasks', () async {
      await db.insertTask(makeTask(id: 'a').copyWith(listId: 'L1'));
      await db.insertTask(makeTask(id: 'b').copyWith(listId: 'L1'));
      await db.insertTask(makeTask(id: 'c').copyWith(listId: 'L2'));

      await db.softDeleteTasksForList('L1', DateTime.now());

      final active = (await db.getTasks()).map((t) => t.id).toSet();
      expect(active, {'c'});
      final trashed = (await db.getTrashedTasks()).map((t) => t.id).toSet();
      expect(trashed, {'a', 'b'});
    });

    test('updateTaskSortOrders writes new sortOrder values', () async {
      await db.insertTask(makeTask(id: 'a', sortOrder: 1));
      await db.insertTask(makeTask(id: 'b', sortOrder: 2));
      final tasks = await db.getTasks();

      // Swap their sort orders.
      final reordered = [
        for (final t in tasks)
          t.copyWith(sortOrder: t.id == 'a' ? 2 : 1),
      ];
      await db.updateTaskSortOrders(reordered);

      final byId = {for (final t in await db.getTasks()) t.id: t.sortOrder};
      expect(byId['a'], 2);
      expect(byId['b'], 1);
    });
  });

  // ── Folders ──────────────────────────────────────────────────────────────────

  group('folders', () {
    AppFolder makeFolder(String id, {int sortOrder = 0}) => AppFolder(
          id: id,
          name: 'Folder $id',
          creationDate: DateTime.now(),
          sortOrder: sortOrder,
        );

    test('insert + get + soft-delete + restore + permanently delete', () async {
      await db.insertFolder(makeFolder('f1'));
      expect((await db.getFolders()).single.id, 'f1');

      await db.softDeleteFolder('f1', DateTime.now());
      expect(await db.getFolders(), isEmpty);
      expect((await db.getTrashedFolders()).single.id, 'f1');

      await db.restoreFolder('f1');
      expect((await db.getFolders()).single.id, 'f1');

      await db.softDeleteFolder('f1', DateTime.now());
      await db.deleteFolder('f1');
      expect(await db.getTrashedFolders(), isEmpty);
    });

    test('updateFolder persists changes', () async {
      await db.insertFolder(makeFolder('f1'));
      final f = (await db.getFolders()).single;
      await db.updateFolder(f.copyWith(name: 'Renamed'));
      expect((await db.getFolders()).single.name, 'Renamed');
    });

    test('clearTrashedFolders empties only trashed', () async {
      await db.insertFolder(makeFolder('keep'));
      await db.insertFolder(makeFolder('drop'));
      await db.softDeleteFolder('drop', DateTime.now());
      await db.clearTrashedFolders();
      expect(await db.getTrashedFolders(), isEmpty);
      expect((await db.getFolders()).single.id, 'keep');
    });
  });

  // ── Lists ────────────────────────────────────────────────────────────────────

  group('lists', () {
    AppList makeList(String id, {int sortOrder = 0}) => AppList(
          id: id,
          name: 'List $id',
          creationDate: DateTime.now(),
          sortOrder: sortOrder,
        );

    test('insert + get + soft-delete + restore + permanently delete', () async {
      await db.insertList(makeList('l1'));
      expect((await db.getLists()).single.id, 'l1');

      await db.softDeleteList('l1', DateTime.now());
      expect(await db.getLists(), isEmpty);
      expect((await db.getTrashedLists()).single.id, 'l1');

      await db.restoreList('l1');
      expect((await db.getLists()).single.id, 'l1');

      await db.softDeleteList('l1', DateTime.now());
      await db.deleteList('l1');
      expect(await db.getTrashedLists(), isEmpty);
    });

    test('updateList persists changes', () async {
      await db.insertList(makeList('l1'));
      final l = (await db.getLists()).single;
      await db.updateList(l.copyWith(name: 'Renamed'));
      expect((await db.getLists()).single.name, 'Renamed');
    });

    test('clearTrashedLists empties only trashed', () async {
      await db.insertList(makeList('keep'));
      await db.insertList(makeList('drop'));
      await db.softDeleteList('drop', DateTime.now());
      await db.clearTrashedLists();
      expect(await db.getTrashedLists(), isEmpty);
      expect((await db.getLists()).single.id, 'keep');
    });
  });

  // ── Note folders ──────────────────────────────────────────────────────────────

  group('note folders', () {
    NoteFolder makeNF(String id) => NoteFolder(
          id: id,
          name: 'NF $id',
          creationDate: DateTime.now(),
        );

    test('insert + get + soft-delete + restore + clear', () async {
      await db.insertNoteFolder(makeNF('nf1'));
      expect((await db.getNoteFolders()).single.id, 'nf1');

      await db.softDeleteNoteFolder('nf1', DateTime.now());
      expect(await db.getNoteFolders(), isEmpty);
      expect((await db.getTrashedNoteFolders()).single.id, 'nf1');

      await db.restoreNoteFolder('nf1');
      expect((await db.getNoteFolders()).single.id, 'nf1');

      await db.softDeleteNoteFolder('nf1', DateTime.now());
      await db.clearTrashedNoteFolders();
      expect(await db.getTrashedNoteFolders(), isEmpty);
    });
  });

  // ── Notes ─────────────────────────────────────────────────────────────────────

  group('notes', () {
    test('insert + getNotes returns active only', () async {
      await db.insertNote(makeNote(id: 'n1', title: 'Hello'));
      final notes = await db.getNotes();
      expect(notes.single.id, 'n1');
      expect(notes.single.title, 'Hello');
    });

    test('getNotes ordering: sortOrder ASC then modifiedDate DESC', () async {
      final base = DateTime(2024, 1, 1, 12);
      await db.insertNote(makeNote(id: 'oldmod', sortOrder: 0, modified: base));
      await db.insertNote(makeNote(
          id: 'newmod',
          sortOrder: 0,
          modified: base.add(const Duration(hours: 1))));
      await db.insertNote(makeNote(
          id: 'sorted',
          sortOrder: 5,
          modified: base.add(const Duration(hours: 2))));

      final ids = (await db.getNotes()).map((n) => n.id).toList();
      expect(ids, ['newmod', 'oldmod', 'sorted']);
    });

    test('update + soft-delete + restore + clear', () async {
      await db.insertNote(makeNote(id: 'n1', title: 'Before'));
      final n = (await db.getNotes()).single;
      await db.updateNote(n.copyWith(title: 'After'));
      expect((await db.getNotes()).single.title, 'After');

      await db.softDeleteNote('n1', DateTime.now());
      expect(await db.getNotes(), isEmpty);
      expect((await db.getTrashedNotes()).single.id, 'n1');

      await db.restoreNote('n1');
      expect((await db.getNotes()).single.id, 'n1');

      await db.softDeleteNote('n1', DateTime.now());
      await db.clearTrashedNotes();
      expect(await db.getTrashedNotes(), isEmpty);
    });
  });

  // ── Contacts ────────────────────────────────────────────────────────────────

  group('contacts', () {
    Contact makeContact(String id,
            {required String listId, int sortOrder = 0, DateTime? creation}) =>
        Contact(
          id: id,
          name: 'Contact $id',
          listId: listId,
          birthMonth: 6,
          birthDay: 15,
          creationDate: creation ?? DateTime.now(),
          sortOrder: sortOrder,
        );

    test('insert + getContacts returns active only', () async {
      await db.insertContact(makeContact('c1', listId: 'L1'));
      expect((await db.getContacts()).single.id, 'c1');
    });

    test('getContacts ordering: sortOrder ASC then creationDate ASC', () async {
      final base = DateTime(2024, 1, 1, 12);
      await db.insertContact(makeContact('early',
          listId: 'L1', sortOrder: 0, creation: base));
      await db.insertContact(makeContact('late',
          listId: 'L1',
          sortOrder: 0,
          creation: base.add(const Duration(hours: 1))));
      await db.insertContact(makeContact('sorted',
          listId: 'L1',
          sortOrder: 5,
          creation: base.subtract(const Duration(hours: 1))));

      final ids = (await db.getContacts()).map((c) => c.id).toList();
      expect(ids, ['early', 'late', 'sorted']);
    });

    test('update + soft-delete + restore + permanently delete + clear',
        () async {
      await db.insertContact(makeContact('c1', listId: 'L1'));
      final c = (await db.getContacts()).single;
      await db.updateContact(c.copyWith(name: 'Renamed'));
      expect((await db.getContacts()).single.name, 'Renamed');

      await db.softDeleteContact('c1', DateTime.now());
      expect(await db.getContacts(), isEmpty);
      expect((await db.getTrashedContacts()).single.id, 'c1');

      await db.restoreContact('c1');
      expect((await db.getContacts()).single.id, 'c1');

      await db.softDeleteContact('c1', DateTime.now());
      await db.permanentlyDeleteContact('c1');
      expect(await db.getTrashedContacts(), isEmpty);
    });

    test('softDeleteContactsForList trashes only that list', () async {
      await db.insertContact(makeContact('a', listId: 'L1'));
      await db.insertContact(makeContact('b', listId: 'L2'));
      await db.softDeleteContactsForList('L1', DateTime.now());
      expect((await db.getContacts()).single.id, 'b');
      expect((await db.getTrashedContacts()).single.id, 'a');
    });

    test('clearTrashedContacts empties only trashed', () async {
      await db.insertContact(makeContact('keep', listId: 'L1'));
      await db.insertContact(makeContact('drop', listId: 'L1'));
      await db.softDeleteContact('drop', DateTime.now());
      await db.clearTrashedContacts();
      expect(await db.getTrashedContacts(), isEmpty);
      expect((await db.getContacts()).single.id, 'keep');
    });
  });

  // ── Events ────────────────────────────────────────────────────────────────────

  group('events', () {
    test('insert + getEvents ordered by date ASC', () async {
      await db.insertEvent(makeEvent(id: 'e2', date: DateTime(2024, 5, 2)));
      await db.insertEvent(makeEvent(id: 'e1', date: DateTime(2024, 5, 1)));
      await db.insertEvent(makeEvent(id: 'e3', date: DateTime(2024, 5, 3)));

      final ids = (await db.getEvents()).map((e) => e.id).toList();
      expect(ids, ['e1', 'e2', 'e3']);
    });

    test('updateEvent persists changes', () async {
      await db.insertEvent(makeEvent(id: 'e1', date: DateTime(2024, 5, 1)));
      final e = (await db.getEvents()).single;
      await db.updateEvent(e.copyWith(title: 'Renamed'));
      expect((await db.getEvents()).single.title, 'Renamed');
    });

    test('permanentlyDeleteEvent removes the row', () async {
      await db.insertEvent(makeEvent(id: 'e1', date: DateTime(2024, 5, 1)));
      await db.permanentlyDeleteEvent('e1');
      expect(await db.getEvents(), isEmpty);
    });
  });

  // ── Routines + routine entries ────────────────────────────────────────────────

  group('routines', () {
    Routine makeRoutine(String id, {DateTime? creation}) => Routine(
          id: id,
          creationDate: creation ?? DateTime.now(),
          iconId: 'star',
          iconColor: 0xFFFF0000,
          name: 'Routine $id',
          goalType: 'achieve_all',
          frequencyType: 'daily',
          autoReset: 'everyday',
        );

    RoutineEntry makeEntry(String id, String routineId,
            {required DateTime date, int amount = 1}) =>
        RoutineEntry(id: id, routineId: routineId, date: date, amount: amount);

    test('insert + getRoutines ordered by creationDate ASC', () async {
      final base = DateTime(2024, 1, 1);
      await db.insertRoutine(makeRoutine('r2',
          creation: base.add(const Duration(days: 1))));
      await db.insertRoutine(makeRoutine('r1', creation: base));
      final ids = (await db.getRoutines()).map((r) => r.id).toList();
      expect(ids, ['r1', 'r2']);
    });

    test('updateRoutine persists changes', () async {
      await db.insertRoutine(makeRoutine('r1'));
      final r = (await db.getRoutines()).single;
      await db.updateRoutine(r.copyWith(name: 'Renamed'));
      expect((await db.getRoutines()).single.name, 'Renamed');
    });

    test('deleteRoutine also deletes its routine_entries', () async {
      await db.insertRoutine(makeRoutine('r1'));
      await db.insertRoutine(makeRoutine('r2'));
      await db.insertRoutineEntry(
          makeEntry('en1', 'r1', date: DateTime(2024, 1, 1)));
      await db.insertRoutineEntry(
          makeEntry('en2', 'r2', date: DateTime(2024, 1, 1)));

      await db.deleteRoutine('r1');

      expect((await db.getRoutines()).single.id, 'r2');
      final remainingEntries =
          (await db.getRoutineEntries()).map((e) => e.id).toSet();
      expect(remainingEntries, {'en2'});
    });

    test('routine entries: insert + get + update', () async {
      await db.insertRoutineEntry(
          makeEntry('en1', 'r1', date: DateTime(2024, 1, 1), amount: 3));
      final entry = (await db.getRoutineEntries()).single;
      expect(entry.amount, 3);

      await db.updateRoutineEntry(entry.copyWith(amount: 7));
      expect((await db.getRoutineEntries()).single.amount, 7);
    });
  });

  // ── List sections ──────────────────────────────────────────────────────────────

  group('list sections', () {
    ListSection makeSection(String id,
            {String listId = 'L1', int sortOrder = 0, DateTime? creation}) =>
        ListSection(
          id: id,
          listId: listId,
          name: 'Section $id',
          sortOrder: sortOrder,
          creationDate: creation ?? DateTime.now(),
        );

    test('insert + getListSections ordered by sortOrder then creationDate',
        () async {
      await db.insertListSection(makeSection('b', sortOrder: 1));
      await db.insertListSection(makeSection('a', sortOrder: 0));
      await db.insertListSection(makeSection('c', sortOrder: 2));
      final ids = (await db.getListSections()).map((s) => s.id).toList();
      expect(ids, ['a', 'b', 'c']);
    });

    test('update + delete', () async {
      await db.insertListSection(makeSection('s1'));
      final s = (await db.getListSections()).single;
      await db.updateListSection(s.copyWith(name: 'Renamed'));
      expect((await db.getListSections()).single.name, 'Renamed');

      await db.deleteListSection('s1');
      expect(await db.getListSections(), isEmpty);
    });

    test('deleteSectionsForList removes only matching list', () async {
      await db.insertListSection(makeSection('a', listId: 'L1'));
      await db.insertListSection(makeSection('b', listId: 'L2'));
      await db.deleteSectionsForList('L1');
      expect((await db.getListSections()).single.id, 'b');
    });
  });

  // ── Tags (raw maps) ────────────────────────────────────────────────────────────

  group('tags', () {
    Map<String, dynamic> tagRow(String id, String name, {int? color}) =>
        Tag(id: id, name: name, color: color, creationDate: DateTime.now())
            .toMap();

    test('insert + getTags ordered by name COLLATE NOCASE', () async {
      await db.insertTag(tagRow('1', 'banana'));
      await db.insertTag(tagRow('2', 'Apple'));
      await db.insertTag(tagRow('3', 'cherry'));
      final names = (await db.getTags()).map((t) => t['name']).toList();
      expect(names, ['Apple', 'banana', 'cherry']);
    });

    test('updateTag changes a row', () async {
      await db.insertTag(tagRow('1', 'old'));
      await db.updateTag(tagRow('1', 'new'));
      final tags = await db.getTags();
      expect(tags.single['name'], 'new');
    });

    test('deleteTag removes a row', () async {
      await db.insertTag(tagRow('1', 'gone'));
      await db.deleteTag('1');
      expect(await db.getTags(), isEmpty);
    });
  });

  // ── App settings ─────────────────────────────────────────────────────────────

  group('app settings', () {
    Future<String?> read(String key) async {
      final rows = await db.getAppSettings();
      for (final r in rows) {
        if (r['key'] == key) return r['value'] as String?;
      }
      return null;
    }

    test('set then read back', () async {
      await db.setAppSetting('accent_color', '123');
      expect(await read('accent_color'), '123');
    });

    test('set overwrites existing key', () async {
      await db.setAppSetting('font', 'roboto');
      await db.setAppSetting('font', 'lato');
      expect(await read('font'), 'lato');
      // Only one row for the key.
      final rows = await db.getAppSettings();
      expect(rows.where((r) => r['key'] == 'font').length, 1);
    });

    test('delete removes a key', () async {
      await db.setAppSetting('locale', 'en');
      await db.deleteAppSetting('locale');
      expect(await read('locale'), isNull);
    });
  });

  // ── Search (FTS5) ─────────────────────────────────────────────────────────────

  group('searchAll', () {
    setUp(() async {
      await db.insertTask(makeTask(id: 'task-groc', title: 'Buy groceries'));
      await db.insertNote(makeNote(id: 'note-groc', title: 'Grocery list'));
      await db.insertEvent(
          makeEvent(id: 'evt-dentist', title: 'Dentist', date: DateTime(2024, 5, 1)));
    });

    test('prefix match hits task + note, not event', () async {
      final r = await db.searchAll('groc');
      expect(r.taskIds, contains('task-groc'));
      expect(r.noteIds, contains('note-groc'));
      expect(r.eventIds, isEmpty);
    });

    test('matches event by title', () async {
      final r = await db.searchAll('dentist');
      expect(r.eventIds, contains('evt-dentist'));
      expect(r.taskIds, isEmpty);
      expect(r.noteIds, isEmpty);
    });

    test('soft-deleted task still appears in FTS (index not updated on soft delete)',
        () async {
      // NOTE: soft delete only flips isDeleted; it does NOT remove the FTS row
      // (only a hard DELETE fires the tasks_ad trigger). Documenting actual
      // behaviour rather than the idealized "excluded from search".
      await db.softDeleteTask('task-groc', DateTime.now());
      final r = await db.searchAll('groceries');
      expect(r.taskIds, contains('task-groc'));
    });

    test('hard-deleted task is removed from FTS index', () async {
      await db.permanentlyDeleteTask('task-groc');
      final r = await db.searchAll('groceries');
      expect(r.taskIds, isEmpty);
    });

    test('no-match query is empty', () async {
      final r = await db.searchAll('zzzznomatch');
      expect(r.isEmpty, isTrue);
      expect(r.total, 0);
    });

    test('blank query returns empty results', () async {
      final r = await db.searchAll('   ');
      expect(r.isEmpty, isTrue);
    });
  });

  // ── replaceAllData ─────────────────────────────────────────────────────────────

  group('replaceAllData', () {
    test('clears existing data and inserts the replacement', () async {
      await db.insertTask(makeTask(id: 'old', title: 'Old'));

      final replacement = makeTask(id: 'new', title: 'New');
      await db.replaceAllData({
        'tasks': [replacement.toMap()],
      });

      final tasks = await db.getTasks();
      expect(tasks.length, 1);
      expect(tasks.single.id, 'new');
      expect(tasks.single.title, 'New');
    });

    test('empty map wipes everything', () async {
      await db.insertTask(makeTask(id: 'old'));
      await db.insertNote(makeNote(id: 'oldnote'));
      await db.replaceAllData({});
      expect(await db.getTasks(), isEmpty);
      expect(await db.getNotes(), isEmpty);
    });

    test('replaces across multiple tables', () async {
      await db.insertTask(makeTask(id: 'old-task'));
      final newNote = makeNote(id: 'new-note', title: 'Kept');
      await db.replaceAllData({
        'notes': [newNote.toMap()],
      });
      expect(await db.getTasks(), isEmpty);
      expect((await db.getNotes()).single.id, 'new-note');
    });
  });

  // ── resetUserData ──────────────────────────────────────────────────────────────

  group('resetUserData', () {
    test('wipes every user table', () async {
      await db.insertTask(makeTask(id: 't1'));
      await db.insertNote(makeNote(id: 'n1'));
      await db.insertEvent(makeEvent(id: 'e1', date: DateTime(2024, 5, 1)));
      await db.insertContact(Contact(
        id: 'c1',
        name: 'C',
        listId: 'L1',
        birthMonth: 1,
        birthDay: 1,
        creationDate: DateTime.now(),
      ));

      await db.resetUserData();

      expect(await db.getTasks(), isEmpty);
      expect(await db.getNotes(), isEmpty);
      expect(await db.getEvents(), isEmpty);
      expect(await db.getContacts(), isEmpty);
    });
  });
}
