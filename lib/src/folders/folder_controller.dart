import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';

class FolderController with ChangeNotifier {
  FolderController(this._db);

  final DatabaseService _db;
  List<AppFolder> _folders = [];
  List<AppList> _lists = [];
  List<AppFolder> _trashedFolders = [];
  List<AppList> _trashedLists = [];

  List<AppFolder> get folders => List.unmodifiable(_folders);
  List<AppList> get lists => List.unmodifiable(_lists);
  List<AppFolder> get trashedFolders => List.unmodifiable(_trashedFolders);
  List<AppList> get trashedLists => List.unmodifiable(_trashedLists);

  List<AppFolder> foldersIn(String? parentId) {
    final result = _folders
        .where((f) => f.parentFolderId == parentId)
        .toList();
    _sortByDefault(result);
    return result;
  }

  List<AppList> listsIn(String? folderId) {
    final result =
        _lists.where((l) => l.folderId == folderId).toList();
    _sortListsByDefault(result);
    return result;
  }

  AppList? listById(String id) {
    try {
      return _lists.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  AppFolder? folderById(String id) {
    try {
      return _folders.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// IDs of every list that lives directly inside [folderId].
  List<String> listIdsIn(String folderId) =>
      _lists.where((l) => l.folderId == folderId).map((l) => l.id).toList();

  /// IDs of every list inside [folderId] **and** every nested subfolder.
  /// Walks the folder tree iteratively to avoid stack growth on deep trees.
  List<String> listIdsInRecursive(String folderId) {
    final ids = <String>[];
    final stack = <String>[folderId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final l in _lists) {
        if (l.folderId == current) ids.add(l.id);
      }
      for (final f in _folders) {
        if (f.parentFolderId == current) stack.add(f.id);
      }
    }
    return ids;
  }

  Future<void> load() async {
    _folders = await _db.getFolders();
    _lists = await _db.getLists();
    _trashedFolders = await _db.getTrashedFolders();
    _trashedLists = await _db.getTrashedLists();
    notifyListeners();
  }

  Future<void> addFolder(AppFolder folder) async {
    await _db.insertFolder(folder);
    _folders = [..._folders, folder];
    notifyListeners();
  }

  Future<void> addList(AppList list) async {
    await _db.insertList(list);
    _lists = [..._lists, list];
    notifyListeners();
  }

  Future<void> updateFolder(AppFolder folder) async {
    await _db.updateFolder(folder);
    final idx = _folders.indexWhere((f) => f.id == folder.id);
    if (idx != -1) _folders[idx] = folder;
    notifyListeners();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    _folders = _folders.where((f) => f.id != id).toList();
    notifyListeners();
  }

  Future<void> updateList(AppList list) async {
    await _db.updateList(list);
    final idx = _lists.indexWhere((l) => l.id == list.id);
    if (idx != -1) _lists[idx] = list;
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    final now = DateTime.now();
    await _db.softDeleteList(id, now);
    final list = _lists.firstWhere((l) => l.id == id,
        orElse: () => AppList(id: id, name: ''));
    _lists = _lists.where((l) => l.id != id).toList();
    _trashedLists = [
      list.copyWith(isDeleted: true, deletedDate: now),
      ..._trashedLists,
    ];
    notifyListeners();
  }

  /// Restores every folder and list that was soft-deleted at exactly
  /// [deletedDate] — used by Revert for folder-deep deletes which mark every
  /// nested item with the same timestamp.
  Future<void> restoreAt(DateTime deletedDate) async {
    final ts = deletedDate.millisecondsSinceEpoch;
    final folders = _trashedFolders
        .where((f) => f.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    final lists = _trashedLists
        .where((l) => l.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    for (final f in folders) {
      await _db.restoreFolder(f.id);
    }
    for (final l in lists) {
      await _db.restoreList(l.id);
    }
    _trashedFolders = _trashedFolders
        .where((f) => f.deletedDate?.millisecondsSinceEpoch != ts)
        .toList();
    _trashedLists = _trashedLists
        .where((l) => l.deletedDate?.millisecondsSinceEpoch != ts)
        .toList();
    _folders = [
      ..._folders,
      ...folders.map((f) =>
          f.copyWith(isDeleted: false, clearDeletedDate: true)),
    ];
    _lists = [
      ..._lists,
      ...lists.map((l) =>
          l.copyWith(isDeleted: false, clearDeletedDate: true)),
    ];
    notifyListeners();
  }

  Future<void> permanentlyDeleteList(String id) async {
    await _db.deleteList(id);
    _trashedLists = _trashedLists.where((l) => l.id != id).toList();
    notifyListeners();
  }

  Future<void> permanentlyDeleteFolder(String id) async {
    await _db.deleteFolder(id);
    _trashedFolders = _trashedFolders.where((f) => f.id != id).toList();
    notifyListeners();
  }

  Future<void> permanentlyDeleteAllTrashed() async {
    await _db.clearTrashedLists();
    await _db.clearTrashedFolders();
    _trashedLists = [];
    _trashedFolders = [];
    notifyListeners();
  }

  Future<void> restoreList(String id, String? targetFolderId) async {
    final i = _trashedLists.indexWhere((l) => l.id == id);
    if (i == -1) return;
    final orig = _trashedLists[i];
    final restored = AppList(
      id: orig.id,
      name: orig.name,
      folderId: targetFolderId,
      creationDate: orig.creationDate,
      sortOrder: orig.sortOrder,
      color: orig.color,
      iconId: orig.iconId,
      iconColor: orig.iconColor,
    );
    await _db.restoreList(id);
    if (targetFolderId != orig.folderId) {
      await _db.updateList(restored);
    }
    _trashedLists = List.of(_trashedLists)..removeAt(i);
    _lists = [..._lists, restored];
    notifyListeners();
  }

  Future<void> restoreFolder(String id, String? targetParentId) async {
    final i = _trashedFolders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    final orig = _trashedFolders[i];
    final restored = AppFolder(
      id: orig.id,
      name: orig.name,
      parentFolderId: targetParentId,
      creationDate: orig.creationDate,
      sortOrder: orig.sortOrder,
      iconId: orig.iconId,
      iconColor: orig.iconColor,
    );
    await _db.restoreFolder(id);
    if (targetParentId != orig.parentFolderId) {
      await _db.updateFolder(restored);
    }
    _trashedFolders = List.of(_trashedFolders)..removeAt(i);
    _folders = [..._folders, restored];
    notifyListeners();
  }

  /// Reorders folders within [parentFolderId] scope using drag indices from
  /// [SliverReorderableList].
  Future<void> reorderFolders(
      String? parentFolderId, int oldIndex, int newIndex) async {
    final scope = _folders
        .where((f) => f.parentFolderId == parentFolderId)
        .toList();
    _sortByDefault(scope);

    if (newIndex > oldIndex) newIndex--;
    final item = scope.removeAt(oldIndex);
    scope.insert(newIndex, item);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i].copyWith(sortOrder: i + 1);
    }
    for (final updated in scope) {
      final idx = _folders.indexWhere((f) => f.id == updated.id);
      if (idx != -1) _folders[idx] = updated;
    }
    notifyListeners();
    await _db.updateFolderSortOrders(scope);
  }

  /// Reorders lists within [folderId] scope.
  Future<void> reorderLists(
      String? folderId, int oldIndex, int newIndex) async {
    final scope =
        _lists.where((l) => l.folderId == folderId).toList();
    _sortListsByDefault(scope);

    if (newIndex > oldIndex) newIndex--;
    final item = scope.removeAt(oldIndex);
    scope.insert(newIndex, item);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i].copyWith(sortOrder: i + 1);
    }
    for (final updated in scope) {
      final idx = _lists.indexWhere((l) => l.id == updated.id);
      if (idx != -1) _lists[idx] = updated;
    }
    notifyListeners();
    await _db.updateListSortOrders(scope);
  }

  /// Recursively soft-deletes a folder, all nested subfolders, all lists inside
  /// them, and calls [onDeleteList] for each deleted list so the caller can
  /// soft-delete associated tasks. Returns the shared `deletedDate` so a
  /// caller can later pass it to [restoreAt] / [TaskController.restoreAt] to
  /// revert the entire subtree in one shot.
  Future<DateTime> deleteFolderDeep(
    String id,
    Future<void> Function(String listId, DateTime deletedDate) onDeleteList,
  ) async {
    final now = DateTime.now();
    await _softDeleteFolderRecursive(id, now, onDeleteList);
    notifyListeners();
    return now;
  }

  Future<void> _softDeleteFolderRecursive(
    String id,
    DateTime deletedDate,
    Future<void> Function(String listId, DateTime deletedDate) onDeleteList,
  ) async {
    for (final f in foldersIn(id)) {
      await _softDeleteFolderRecursive(f.id, deletedDate, onDeleteList);
    }
    for (final l in listsIn(id)) {
      await onDeleteList(l.id, deletedDate);
      await _db.softDeleteList(l.id, deletedDate);
      _lists = _lists.where((x) => x.id != l.id).toList();
      _trashedLists = [
        l.copyWith(isDeleted: true, deletedDate: deletedDate),
        ..._trashedLists,
      ];
    }
    await _db.softDeleteFolder(id, deletedDate);
    final folder = _folders.firstWhere((f) => f.id == id,
        orElse: () => AppFolder(id: id, name: ''));
    _folders = _folders.where((f) => f.id != id).toList();
    _trashedFolders = [
      folder.copyWith(isDeleted: true, deletedDate: deletedDate),
      ..._trashedFolders,
    ];
  }

  static void _sortByDefault(List<AppFolder> list) {
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.creationDate.compareTo(b.creationDate);
    });
  }

  static void _sortListsByDefault(List<AppList> list) {
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.creationDate.compareTo(b.creationDate);
    });
  }
}
