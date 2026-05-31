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
    db = await freshDb();
    c = FolderController(db);
    await c.load();
  });

  AppFolder makeFolder(String name, {String? parentFolderId, int sortOrder = 0}) {
    return AppFolder(
      id: 'f_$name',
      name: name,
      parentFolderId: parentFolderId,
      sortOrder: sortOrder,
      creationDate: DateTime.now(),
    );
  }

  AppList makeList(String name, {String? folderId, int sortOrder = 0}) {
    return AppList(
      id: 'l_$name',
      name: name,
      folderId: folderId,
      sortOrder: sortOrder,
      creationDate: DateTime.now(),
    );
  }

  ListSection makeSection(String id, String listId,
      {int sortOrder = 0, String name = 'sec'}) {
    return ListSection(
      id: id,
      listId: listId,
      name: name,
      sortOrder: sortOrder,
      creationDate: DateTime.now(),
    );
  }

  group('folders & lists CRUD', () {
    test('addFolder / updateFolder / folderById', () async {
      final f = makeFolder('A');
      await c.addFolder(f);
      expect(c.folderById(f.id)?.name, 'A');

      await c.updateFolder(f.copyWith(name: 'A2'));
      expect(c.folderById(f.id)?.name, 'A2');
    });

    test('addList / updateList / listById', () async {
      final l = makeList('L');
      await c.addList(l);
      expect(c.listById(l.id)?.name, 'L');

      await c.updateList(l.copyWith(name: 'L2'));
      expect(c.listById(l.id)?.name, 'L2');
    });
  });

  group('foldersIn / listsIn direct children', () {
    test('returns only direct children, sorted', () async {
      final parent = makeFolder('parent', sortOrder: 1);
      await c.addFolder(parent);

      final sub = makeFolder('sub', parentFolderId: parent.id, sortOrder: 1);
      await c.addFolder(sub);

      final rootList = makeList('rootList', sortOrder: 1);
      await c.addList(rootList);

      final innerList = makeList('innerList', folderId: parent.id, sortOrder: 1);
      await c.addList(innerList);

      // foldersIn(null) returns only root-level folders
      final rootFolders = c.foldersIn(null);
      expect(rootFolders.map((e) => e.id), contains(parent.id));
      expect(rootFolders.map((e) => e.id), isNot(contains(sub.id)));

      // foldersIn(parent) returns the subfolder
      final children = c.foldersIn(parent.id);
      expect(children.map((e) => e.id), [sub.id]);

      // listsIn(null) returns only root list
      final rootLists = c.listsIn(null);
      expect(rootLists.map((e) => e.id), contains(rootList.id));
      expect(rootLists.map((e) => e.id), isNot(contains(innerList.id)));

      // listsIn(parent) returns inner list
      final inner = c.listsIn(parent.id);
      expect(inner.map((e) => e.id), [innerList.id]);
    });

    test('sorted by sortOrder then creationDate', () async {
      final a = AppFolder(
          id: 'sa',
          name: 'a',
          sortOrder: 2,
          creationDate: DateTime(2020, 1, 1));
      final b = AppFolder(
          id: 'sb',
          name: 'b',
          sortOrder: 1,
          creationDate: DateTime(2020, 1, 2));
      await c.addFolder(a);
      await c.addFolder(b);
      final ids = c.foldersIn(null).map((e) => e.id).toList();
      expect(ids.indexOf('sb'), lessThan(ids.indexOf('sa')));
    });
  });

  group('listIdsInRecursive', () {
    test('returns lists from folder and nested subfolders', () async {
      final a = makeFolder('A');
      await c.addFolder(a);
      final b = makeFolder('B', parentFolderId: a.id);
      await c.addFolder(b);

      final lA = makeList('inA', folderId: a.id);
      final lB = makeList('inB', folderId: b.id);
      await c.addList(lA);
      await c.addList(lB);

      final ids = c.listIdsInRecursive(a.id);
      expect(ids, containsAll([lA.id, lB.id]));
    });
  });

  group('soft delete / restore lists', () {
    test('deleteList soft-deletes; restoreList; permanentlyDeleteList',
        () async {
      final f = makeFolder('F');
      await c.addFolder(f);
      final l = makeList('L', folderId: f.id);
      await c.addList(l);

      await c.deleteList(l.id);
      expect(c.listById(l.id), isNull);
      expect(c.trashedLists.map((e) => e.id), contains(l.id));

      await c.restoreList(l.id, f.id);
      expect(c.listById(l.id)?.folderId, f.id);
      expect(c.trashedLists.map((e) => e.id), isNot(contains(l.id)));

      // permanent delete
      await c.deleteList(l.id);
      await c.permanentlyDeleteList(l.id);
      expect(c.trashedLists.map((e) => e.id), isNot(contains(l.id)));
      expect(c.listById(l.id), isNull);
    });
  });

  group('deleteFolder / deleteFolderDeep', () {
    test('deleteFolderDeep soft-deletes folder tree and calls callback',
        () async {
      final a = makeFolder('A');
      await c.addFolder(a);
      final b = makeFolder('B', parentFolderId: a.id);
      await c.addFolder(b);
      final lA = makeList('inA', folderId: a.id);
      final lB = makeList('inB', folderId: b.id);
      await c.addList(lA);
      await c.addList(lB);

      final recorded = <MapEntry<String, DateTime>>[];
      final shared = await c.deleteFolderDeep(a.id, (listId, date) {
        recorded.add(MapEntry(listId, date));
      });

      // folders gone from active
      expect(c.folderById(a.id), isNull);
      expect(c.folderById(b.id), isNull);
      expect(c.trashedFolders.map((e) => e.id), containsAll([a.id, b.id]));

      // callback invoked for each nested list with shared timestamp
      expect(recorded.map((e) => e.key), containsAll([lA.id, lB.id]));
      for (final e in recorded) {
        expect(e.value, shared);
      }

      // restoreAt brings everything back
      await c.restoreAt(shared);
      expect(c.folderById(a.id), isNotNull);
      expect(c.folderById(b.id), isNotNull);
    });
  });

  group('reorder', () {
    test('reorderFolders updates order and persisted sortOrder', () async {
      final f1 = makeFolder('1', sortOrder: 1);
      final f2 = makeFolder('2', sortOrder: 2);
      final f3 = makeFolder('3', sortOrder: 3);
      await c.addFolder(f1);
      await c.addFolder(f2);
      await c.addFolder(f3);

      // move first to last
      await c.reorderFolders(null, 0, 2);
      final order = c.foldersIn(null).map((e) => e.id).toList();
      expect(order, [f2.id, f3.id, f1.id]);

      // persisted: reload fresh controller
      final c2 = FolderController(db);
      await c2.load();
      expect(c2.foldersIn(null).map((e) => e.id).toList(),
          [f2.id, f3.id, f1.id]);
    });

    test('reorderLists updates order and persisted sortOrder', () async {
      final f = makeFolder('F');
      await c.addFolder(f);
      final l1 = makeList('1', folderId: f.id, sortOrder: 1);
      final l2 = makeList('2', folderId: f.id, sortOrder: 2);
      final l3 = makeList('3', folderId: f.id, sortOrder: 3);
      await c.addList(l1);
      await c.addList(l2);
      await c.addList(l3);

      await c.reorderLists(f.id, 0, 2);
      final order = c.listsIn(f.id).map((e) => e.id).toList();
      expect(order, [l2.id, l3.id, l1.id]);

      final c2 = FolderController(db);
      await c2.load();
      expect(c2.listsIn(f.id).map((e) => e.id).toList(), [l2.id, l3.id, l1.id]);
    });
  });

  group('sections', () {
    test('add / sectionsForList sorted / sectionById / update / delete',
        () async {
      final l = makeList('L');
      await c.addList(l);

      final s1 = makeSection('s1', l.id, sortOrder: 2, name: 'one');
      final s2 = makeSection('s2', l.id, sortOrder: 1, name: 'two');
      await c.addSection(s1);
      await c.addSection(s2);

      // sorted by sortOrder
      expect(c.sectionsForList(l.id).map((e) => e.id).toList(), ['s2', 's1']);

      expect(c.sectionById('s1')?.name, 'one');

      await c.updateSection(s1.copyWith(name: 'one-x'));
      expect(c.sectionById('s1')?.name, 'one-x');

      await c.deleteSection('s1');
      expect(c.sectionById('s1'), isNull);
      expect(c.sectionsForList(l.id).map((e) => e.id).toList(), ['s2']);
    });

    test('reorderSections', () async {
      final l = makeList('L');
      await c.addList(l);
      final a = makeSection('a', l.id, sortOrder: 1);
      final b = makeSection('b', l.id, sortOrder: 2);
      final cc = makeSection('c', l.id, sortOrder: 3);
      await c.addSection(a);
      await c.addSection(b);
      await c.addSection(cc);

      await c.reorderSections(l.id, 0, 2);
      expect(c.sectionsForList(l.id).map((e) => e.id).toList(), ['b', 'c', 'a']);
    });

    test('toggleSectionCollapsed flips isCollapsed', () async {
      final l = makeList('L');
      await c.addList(l);
      final s = makeSection('s', l.id);
      await c.addSection(s);
      final before = c.sectionById('s')!.isCollapsed;

      await c.toggleSectionCollapsed('s');
      expect(c.sectionById('s')!.isCollapsed, !before);

      await c.toggleSectionCollapsed('s');
      expect(c.sectionById('s')!.isCollapsed, before);
    });
  });
}
