import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/note.dart';
import 'package:planom/src/models/note_folder.dart';
import 'package:planom/src/notes/note_controller.dart';

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

  Note note(String id, String title,
          {String? folderId,
          int sortOrder = 0,
          DateTime? modified,
          DateTime? created}) =>
      Note(
        id: id,
        title: title,
        content: '$title body',
        folderId: folderId,
        sortOrder: sortOrder,
        modifiedDate: modified,
        creationDate: created,
      );

  NoteFolder folder(String id, String name,
          {String? parent, int sortOrder = 0, DateTime? created}) =>
      NoteFolder(
        id: id,
        name: name,
        parentFolderId: parent,
        sortOrder: sortOrder,
        creationDate: created,
      );

  group('add / update / lookup', () {
    test('addNote + noteById; updateNote persists', () async {
      await c.addNote(note('n1', 'Hello'));
      expect(c.noteById('n1')!.title, 'Hello');
      expect(c.noteById('nope'), isNull);

      await c.updateNote(c.noteById('n1')!.copyWith(title: 'Bye'));
      expect(c.noteById('n1')!.title, 'Bye');

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.noteById('n1')!.title, 'Bye');
    });

    test('addFolder + folderById; updateFolder persists', () async {
      await c.addFolder(folder('f1', 'Work'));
      expect(c.folderById('f1')!.name, 'Work');
      expect(c.folderById('nope'), isNull);

      await c.updateFolder(c.folderById('f1')!.copyWith(name: 'Office'));
      expect(c.folderById('f1')!.name, 'Office');

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.folderById('f1')!.name, 'Office');
    });
  });

  group('notesIn / foldersIn direct children + sort', () {
    test('direct children only', () async {
      await c.addFolder(folder('root', 'Root'));
      await c.addFolder(folder('sub', 'Sub', parent: 'root'));
      await c.addNote(note('inside', 'Inside', folderId: 'root'));
      await c.addNote(note('rootNote', 'RootNote'));

      expect(c.foldersIn(null).map((f) => f.id), ['root']);
      expect(c.foldersIn('root').map((f) => f.id), ['sub']);
      expect(c.notesIn('root').map((n) => n.id), ['inside']);
      expect(c.notesIn(null).map((n) => n.id), ['rootNote']);
    });

    test('notes sort: sortOrder then modifiedDate DESC', () async {
      final base = DateTime(2024, 1, 1);
      await c.addNote(note('older', 'Older',
          sortOrder: 0, modified: base.add(const Duration(days: 1))));
      await c.addNote(note('newer', 'Newer',
          sortOrder: 0, modified: base.add(const Duration(days: 5))));
      await c.addNote(note('z', 'Z',
          sortOrder: 9, modified: base.add(const Duration(days: 99))));

      expect(c.notesIn(null).map((n) => n.id), ['newer', 'older', 'z']);
    });

    test('folders sort: sortOrder then creationDate', () async {
      final base = DateTime(2024, 1, 1);
      await c.addFolder(folder('a', 'A',
          sortOrder: 0, created: base.add(const Duration(days: 2))));
      await c.addFolder(folder('b', 'B', sortOrder: 0, created: base));
      await c.addFolder(folder('cc', 'C', sortOrder: 5, created: base));
      expect(c.foldersIn(null).map((f) => f.id), ['b', 'a', 'cc']);
    });
  });

  group('moveNote', () {
    test('changes folderId but preserves modifiedDate', () async {
      final oldModified = DateTime(2020, 6, 1, 12);
      await c.addFolder(folder('dest', 'Dest'));
      await c.addNote(note('n1', 'Note', modified: oldModified));

      await c.moveNote('n1', 'dest');
      final moved = c.noteById('n1')!;
      expect(moved.folderId, 'dest');
      expect(moved.modifiedDate, oldModified);

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.noteById('n1')!.folderId, 'dest');
      expect(c2.noteById('n1')!.modifiedDate, oldModified);
    });

    test('moving to same folder is a no-op (modifiedDate unchanged)', () async {
      final oldModified = DateTime(2020, 6, 1, 12);
      await c.addNote(note('n1', 'Note', modified: oldModified));
      await c.moveNote('n1', null); // already root
      expect(c.noteById('n1')!.modifiedDate, oldModified);
      expect(c.noteById('n1')!.folderId, isNull);
    });
  });

  group('note soft-delete lifecycle', () {
    test('deleteNote soft-deletes preserving modifiedDate', () async {
      final oldModified = DateTime(2020, 6, 1, 12);
      await c.addNote(note('n1', 'Note', modified: oldModified));
      await c.deleteNote('n1');

      expect(c.noteById('n1'), isNull);
      final trashed = c.trashedNotes.firstWhere((n) => n.id == 'n1');
      expect(trashed.isDeleted, isTrue);
      expect(trashed.deletedDate, isNotNull);
      expect(trashed.modifiedDate, oldModified);

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.trashedNotes.map((n) => n.id), contains('n1'));
    });

    test('restoreNote restores into target folder', () async {
      await c.addFolder(folder('dest', 'Dest'));
      await c.addNote(note('n1', 'Note'));
      await c.deleteNote('n1');
      await c.restoreNote('n1', 'dest');

      expect(c.trashedNotes.map((n) => n.id), isNot(contains('n1')));
      expect(c.noteById('n1')!.folderId, 'dest');
    });

    test('permanentlyDeleteNote + permanentlyDeleteAllTrashed', () async {
      await c.addNote(note('n1', 'One'));
      await c.addNote(note('n2', 'Two'));
      await c.deleteNote('n1');
      await c.deleteNote('n2');

      await c.permanentlyDeleteNote('n1');
      expect(c.trashedNotes.map((n) => n.id), isNot(contains('n1')));
      expect(c.trashedNotes.map((n) => n.id), contains('n2'));

      await c.permanentlyDeleteAllTrashed();
      expect(c.trashedNotes, isEmpty);

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.trashedNotes, isEmpty);
      expect(c2.noteById('n1'), isNull);
      expect(c2.noteById('n2'), isNull);
    });
  });

  group('deleteFolderDeep', () {
    test('returns shared deletedDate, recursive soft-delete, restoreAt',
        () async {
      final oldModified = DateTime(2019, 1, 1);
      await c.addFolder(folder('A', 'A'));
      await c.addFolder(folder('B', 'B', parent: 'A'));
      await c.addNote(note('na', 'NA', folderId: 'A', modified: oldModified));
      await c.addNote(note('nb', 'NB', folderId: 'B', modified: oldModified));
      await c.addNote(note('outside', 'Outside'));

      final deletedDate = await c.deleteFolderDeep('A');
      expect(deletedDate, isA<DateTime>());

      expect(c.folderById('A'), isNull);
      expect(c.folderById('B'), isNull);
      expect(c.noteById('na'), isNull);
      expect(c.noteById('nb'), isNull);
      expect(c.noteById('outside'), isNotNull);

      expect(c.trashedFolders.map((f) => f.id), containsAll(['A', 'B']));
      expect(c.trashedNotes.map((n) => n.id), containsAll(['na', 'nb']));
      for (final f in c.trashedFolders) {
        expect(f.deletedDate, deletedDate);
      }
      for (final n in c.trashedNotes) {
        expect(n.deletedDate, deletedDate);
        expect(n.modifiedDate, oldModified); // preserved
      }

      await c.restoreAt(deletedDate);
      expect(c.folderById('A'), isNotNull);
      expect(c.folderById('B'), isNotNull);
      expect(c.noteById('na')!.modifiedDate, oldModified);
      expect(c.noteById('nb')!.modifiedDate, oldModified);
      expect(c.trashedFolders, isEmpty);
      expect(c.trashedNotes, isEmpty);
    });
  });

  group('reorderNotes / reorderNoteFolders', () {
    test('reorderNotes updates order, persists, preserves modifiedDate',
        () async {
      final m = DateTime(2020, 1, 1);
      await c.addNote(note('a', 'A', sortOrder: 1, modified: m));
      await c.addNote(note('b', 'B', sortOrder: 2, modified: m));
      await c.addNote(note('cc', 'C', sortOrder: 3, modified: m));
      await c.reorderNotes(null, 0, 3); // [b,c,a]

      expect(c.notesIn(null).map((n) => n.id), ['b', 'cc', 'a']);
      expect(c.noteById('b')!.sortOrder, 1);
      expect(c.noteById('a')!.modifiedDate, m); // preserved

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.notesIn(null).map((n) => n.id), ['b', 'cc', 'a']);
    });

    test('reorderNoteFolders updates order + persisted sortOrder', () async {
      await c.addFolder(folder('a', 'A', sortOrder: 1));
      await c.addFolder(folder('b', 'B', sortOrder: 2));
      await c.addFolder(folder('cc', 'C', sortOrder: 3));
      await c.reorderNoteFolders(null, 2, 0); // [c,a,b]

      expect(c.foldersIn(null).map((f) => f.id), ['cc', 'a', 'b']);
      expect(c.folderById('cc')!.sortOrder, 1);

      final c2 = NoteController(db);
      await c2.load();
      expect(c2.foldersIn(null).map((f) => f.id), ['cc', 'a', 'b']);
    });

    // NOTE: reorderNoteBefore only reorders within the SAME folder scope; it
    // does NOT change folderId (unlike the folder controller's variants).
    test('reorderNoteBefore moves note before target within scope', () async {
      final m = DateTime(2020, 1, 1);
      await c.addNote(note('a', 'A', sortOrder: 1, modified: m));
      await c.addNote(note('b', 'B', sortOrder: 2, modified: m));
      await c.addNote(note('cc', 'C', sortOrder: 3, modified: m));
      await c.reorderNoteBefore(movedId: 'cc', beforeId: 'a', folderId: null);
      expect(c.notesIn(null).map((n) => n.id), ['cc', 'a', 'b']);
      expect(c.noteById('cc')!.modifiedDate, m); // preserved
      expect(c.noteById('cc')!.folderId, isNull); // scope unchanged

      // beforeId == null => moves to end.
      await c.reorderNoteBefore(movedId: 'cc', beforeId: null, folderId: null);
      expect(c.notesIn(null).map((n) => n.id), ['a', 'b', 'cc']);
    });

    test('reorderNoteFolderBefore moves folder before target within scope',
        () async {
      await c.addFolder(folder('a', 'A', sortOrder: 1));
      await c.addFolder(folder('b', 'B', sortOrder: 2));
      await c.addFolder(folder('cc', 'C', sortOrder: 3));
      await c.reorderNoteFolderBefore(
          movedId: 'cc', beforeId: 'a', parentFolderId: null);
      expect(c.foldersIn(null).map((f) => f.id), ['cc', 'a', 'b']);
      expect(c.folderById('cc')!.parentFolderId, isNull); // scope unchanged

      await c.reorderNoteFolderBefore(
          movedId: 'cc', beforeId: null, parentFolderId: null);
      expect(c.foldersIn(null).map((f) => f.id), ['a', 'b', 'cc']);
    });
  });
}
