import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/models/app_folder.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/models/list_section.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late FolderController c;

  setUp(() async {
    db = freshDb();
    c = FolderController(db);
    await c.load();
  });

  AppFolder folder(String id, String name,
          {String? parent, int sortOrder = 0, DateTime? created}) =>
      AppFolder(
        id: id,
        name: name,
        parentFolderId: parent,
        sortOrder: sortOrder,
        creationDate: created,
      );

  AppList list(String id, String name,
          {String? folderId, int sortOrder = 0, DateTime? created}) =>
      AppList(
        id: id,
        name: name,
        folderId: folderId,
        sortOrder: sortOrder,
        creationDate: created,
      );

  group('add / update / lookup', () {
    test('addFolder + folderById', () async {
      await c.addFolder(folder('f1', 'Work'));
      expect(c.folderById('f1')!.name, 'Work');
      expect(c.folderById('nope'), isNull);
    });

    test('addList + listById', () async {
      await c.addList(list('l1', 'Tasks'));
      expect(c.listById('l1')!.name, 'Tasks');
      expect(c.listById('nope'), isNull);
    });

    test('updateFolder persists', () async {
      await c.addFolder(folder('f1', 'Work'));
      await c.updateFolder(c.folderById('f1')!.copyWith(name: 'Office'));
      expect(c.folderById('f1')!.name, 'Office');

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.folderById('f1')!.name, 'Office');
    });

    test('updateList persists', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.updateList(c.listById('l1')!.copyWith(name: 'Errands'));
      expect(c.listById('l1')!.name, 'Errands');

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.listById('l1')!.name, 'Errands');
    });
  });

  group('foldersIn / listsIn direct children + sort', () {
    test('returns only direct children', () async {
      await c.addFolder(folder('root', 'Root'));
      await c.addFolder(folder('sub', 'Sub', parent: 'root'));
      await c.addFolder(folder('rootB', 'RootB'));
      await c.addList(list('inside', 'Inside', folderId: 'root'));
      await c.addList(list('rootList', 'RootList'));

      final topFolders = c.foldersIn(null);
      expect(topFolders.map((f) => f.id), containsAll(['root', 'rootB']));
      expect(topFolders.map((f) => f.id), isNot(contains('sub')));

      expect(c.foldersIn('root').map((f) => f.id), ['sub']);
      expect(c.listsIn('root').map((l) => l.id), ['inside']);
      expect(c.listsIn(null).map((l) => l.id), ['rootList']);
    });

    test('folders default sort: sortOrder then creationDate', () async {
      final base = DateTime(2024, 1, 1);
      await c.addFolder(folder('a', 'A',
          sortOrder: 0, created: base.add(const Duration(days: 2))));
      await c.addFolder(folder('b', 'B',
          sortOrder: 0, created: base.add(const Duration(days: 1))));
      await c.addFolder(folder('cc', 'C', sortOrder: 5, created: base));

      expect(c.foldersIn(null).map((f) => f.id), ['b', 'a', 'cc']);
    });

    test('lists default sort: sortOrder then creationDate', () async {
      final base = DateTime(2024, 1, 1);
      await c.addList(list('a', 'A',
          sortOrder: 2, created: base.add(const Duration(days: 1))));
      await c.addList(list('b', 'B', sortOrder: 1, created: base));
      expect(c.listsIn(null).map((l) => l.id), ['b', 'a']);
    });
  });

  group('listIdsIn / listIdsInRecursive', () {
    test('recursive gathers lists from folder and nested subfolders', () async {
      await c.addFolder(folder('A', 'A'));
      await c.addFolder(folder('B', 'B', parent: 'A'));
      await c.addList(list('la', 'LA', folderId: 'A'));
      await c.addList(list('lb', 'LB', folderId: 'B'));
      await c.addList(list('outside', 'Outside'));

      expect(c.listIdsIn('A'), ['la']);
      expect(c.listIdsInRecursive('A'), containsAll(['la', 'lb']));
      expect(c.listIdsInRecursive('A'), isNot(contains('outside')));
      expect(c.listIdsInRecursive('A').length, 2);
    });
  });

  group('list soft-delete lifecycle', () {
    test('deleteList soft-deletes into trashedLists', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.deleteList('l1');

      expect(c.listById('l1'), isNull);
      expect(c.trashedLists.map((l) => l.id), contains('l1'));
      expect(c.trashedLists.first.isDeleted, isTrue);
      expect(c.trashedLists.first.deletedDate, isNotNull);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.trashedLists.map((l) => l.id), contains('l1'));
    });

    test('restoreList puts it back into target folder', () async {
      await c.addFolder(folder('dest', 'Dest'));
      await c.addList(list('l1', 'Tasks'));
      await c.deleteList('l1');
      await c.restoreList('l1', 'dest');

      expect(c.trashedLists.map((l) => l.id), isNot(contains('l1')));
      expect(c.listById('l1')!.folderId, 'dest');
    });

    test('permanentlyDeleteList removes from trash & DB', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.deleteList('l1');
      await c.permanentlyDeleteList('l1');

      expect(c.trashedLists.map((l) => l.id), isNot(contains('l1')));
      final c2 = FolderController(db);
      await c2.load();
      expect(c2.trashedLists.map((l) => l.id), isNot(contains('l1')));
      expect(c2.listById('l1'), isNull);
    });
  });

  group('deleteFolder', () {
    // deleteFolder is a HARD delete: removes the row from the DB and from
    // _folders, and does NOT add it to trashedFolders.
    test('deleteFolder is a hard delete (not soft)', () async {
      await c.addFolder(folder('f1', 'Work'));
      await c.deleteFolder('f1');

      expect(c.folderById('f1'), isNull);
      expect(c.trashedFolders.map((f) => f.id), isNot(contains('f1')));

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.folderById('f1'), isNull);
      expect(c2.trashedFolders.map((f) => f.id), isNot(contains('f1')));
    });
  });

  group('deleteFolderDeep', () {
    test('recursively soft-deletes + callback per list + restoreAt', () async {
      await c.addFolder(folder('A', 'A'));
      await c.addFolder(folder('B', 'B', parent: 'A'));
      await c.addList(list('la', 'LA', folderId: 'A'));
      await c.addList(list('lb', 'LB', folderId: 'B'));

      final calls = <(String, DateTime)>[];
      final deletedDate =
          await c.deleteFolderDeep('A', (listId, date) async {
        calls.add((listId, date));
      });

      expect(calls.map((e) => e.$1), containsAll(['la', 'lb']));
      expect(calls.length, 2);
      for (final call in calls) {
        expect(call.$2, deletedDate);
      }

      expect(c.folderById('A'), isNull);
      expect(c.folderById('B'), isNull);
      expect(c.listById('la'), isNull);
      expect(c.listById('lb'), isNull);
      expect(c.trashedFolders.map((f) => f.id), containsAll(['A', 'B']));
      expect(c.trashedLists.map((l) => l.id), containsAll(['la', 'lb']));
      for (final f in c.trashedFolders) {
        expect(f.deletedDate, deletedDate);
      }
      for (final l in c.trashedLists) {
        expect(l.deletedDate, deletedDate);
      }

      await c.restoreAt(deletedDate);
      expect(c.folderById('A'), isNotNull);
      expect(c.folderById('B'), isNotNull);
      expect(c.listById('la'), isNotNull);
      expect(c.listById('lb'), isNotNull);
      expect(c.trashedFolders, isEmpty);
      expect(c.trashedLists, isEmpty);
    });
  });

  group('reorderFolders / reorderLists', () {
    test('reorderFolders updates order + persisted sortOrder', () async {
      await c.addFolder(folder('a', 'A', sortOrder: 1));
      await c.addFolder(folder('b', 'B', sortOrder: 2));
      await c.addFolder(folder('cc', 'C', sortOrder: 3));
      await c.reorderFolders(null, 0, 3); // [a,b,c] -> [b,c,a]

      expect(c.foldersIn(null).map((f) => f.id), ['b', 'cc', 'a']);
      expect(c.folderById('b')!.sortOrder, 1);
      expect(c.folderById('cc')!.sortOrder, 2);
      expect(c.folderById('a')!.sortOrder, 3);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.foldersIn(null).map((f) => f.id), ['b', 'cc', 'a']);
    });

    test('reorderLists updates order + persisted sortOrder', () async {
      await c.addList(list('a', 'A', sortOrder: 1));
      await c.addList(list('b', 'B', sortOrder: 2));
      await c.addList(list('cc', 'C', sortOrder: 3));
      await c.reorderLists(null, 2, 0); // move C to front => [c,a,b]

      expect(c.listsIn(null).map((l) => l.id), ['cc', 'a', 'b']);
      expect(c.listById('cc')!.sortOrder, 1);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.listsIn(null).map((l) => l.id), ['cc', 'a', 'b']);
    });

    // NOTE: reorderFolderBefore only reorders within the SAME parent scope;
    // it sets sortOrder but does NOT change parentFolderId.
    test('reorderFolderBefore moves folder before target within scope',
        () async {
      await c.addFolder(folder('a', 'A', sortOrder: 1));
      await c.addFolder(folder('b', 'B', sortOrder: 2));
      await c.addFolder(folder('cc', 'C', sortOrder: 3));
      await c.reorderFolderBefore(
          movedId: 'cc', beforeId: 'a', parentFolderId: null);
      expect(c.foldersIn(null).map((f) => f.id), ['cc', 'a', 'b']);
      expect(c.folderById('cc')!.parentFolderId, isNull); // scope unchanged
      expect(c.folderById('cc')!.sortOrder, 1);

      // beforeId == null => moves to end of the scope.
      await c.reorderFolderBefore(
          movedId: 'cc', beforeId: null, parentFolderId: null);
      expect(c.foldersIn(null).map((f) => f.id), ['a', 'b', 'cc']);
    });

    test('reorderListBefore moves list before target within scope', () async {
      await c.addList(list('a', 'A', sortOrder: 1));
      await c.addList(list('b', 'B', sortOrder: 2));
      await c.addList(list('cc', 'C', sortOrder: 3));
      await c.reorderListBefore(movedId: 'cc', beforeId: 'a', folderId: null);
      expect(c.listsIn(null).map((l) => l.id), ['cc', 'a', 'b']);
      expect(c.listById('cc')!.folderId, isNull); // scope unchanged

      await c.reorderListBefore(movedId: 'cc', beforeId: null, folderId: null);
      expect(c.listsIn(null).map((l) => l.id), ['a', 'b', 'cc']);
    });
  });

  group('sections', () {
    ListSection section(String id, String listId, String name,
            {int sortOrder = 0, DateTime? created}) =>
        ListSection(
          id: id,
          listId: listId,
          name: name,
          sortOrder: sortOrder,
          creationDate: created,
        );

    test('addSection + sectionsForList sorted + sectionById', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.addSection(section('s2', 'l1', 'Second', sortOrder: 2));
      await c.addSection(section('s1', 'l1', 'First', sortOrder: 1));
      await c.addSection(section('other', 'lX', 'Other', sortOrder: 1));

      expect(c.sectionsForList('l1').map((s) => s.id), ['s1', 's2']);
      expect(c.sectionById('s1')!.name, 'First');
      expect(c.sectionById('missing'), isNull);
    });

    test('updateSection persists', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.addSection(section('s1', 'l1', 'First'));
      await c.updateSection(c.sectionById('s1')!.copyWith(name: 'Renamed'));
      expect(c.sectionById('s1')!.name, 'Renamed');

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.sectionById('s1')!.name, 'Renamed');
    });

    test('deleteSection hard-deletes', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.addSection(section('s1', 'l1', 'First'));
      await c.deleteSection('s1');
      expect(c.sectionById('s1'), isNull);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.sectionById('s1'), isNull);
    });

    test('reorderSections updates order + persisted sortOrder', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.addSection(section('s1', 'l1', 'One', sortOrder: 1));
      await c.addSection(section('s2', 'l1', 'Two', sortOrder: 2));
      await c.addSection(section('s3', 'l1', 'Three', sortOrder: 3));
      await c.reorderSections('l1', 0, 3); // [s2,s3,s1]

      expect(c.sectionsForList('l1').map((s) => s.id), ['s2', 's3', 's1']);
      expect(c.sectionById('s2')!.sortOrder, 1);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.sectionsForList('l1').map((s) => s.id), ['s2', 's3', 's1']);
    });

    test('toggleSectionCollapsed flips isCollapsed', () async {
      await c.addList(list('l1', 'Tasks'));
      await c.addSection(section('s1', 'l1', 'One'));
      expect(c.sectionById('s1')!.isCollapsed, isFalse);
      await c.toggleSectionCollapsed('s1');
      expect(c.sectionById('s1')!.isCollapsed, isTrue);
      await c.toggleSectionCollapsed('s1');
      expect(c.sectionById('s1')!.isCollapsed, isFalse);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.sectionById('s1')!.isCollapsed, isFalse);
    });
  });
}
