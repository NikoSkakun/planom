import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';

class FolderController with ChangeNotifier {
  FolderController(this._db);

  final DatabaseService _db;
  List<AppFolder> _folders = [];
  List<AppList> _lists = [];

  List<AppFolder> get folders => List.unmodifiable(_folders);
  List<AppList> get lists => List.unmodifiable(_lists);

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

  Future<void> load() async {
    _folders = await _db.getFolders();
    _lists = await _db.getLists();
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
    await _db.deleteList(id);
    _lists = _lists.where((l) => l.id != id).toList();
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
    await _db.updateFolderSortOrders(scope);
    notifyListeners();
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
    await _db.updateListSortOrders(scope);
    notifyListeners();
  }

  /// Recursively deletes a folder, all nested subfolders, all lists inside
  /// them, and calls [onDeleteList] for each deleted list so the caller can
  /// clean up associated tasks.
  Future<void> deleteFolderDeep(
    String id,
    Future<void> Function(String listId) onDeleteList,
  ) async {
    await _deleteFolderRecursive(id, onDeleteList);
    notifyListeners();
  }

  Future<void> _deleteFolderRecursive(
    String id,
    Future<void> Function(String listId) onDeleteList,
  ) async {
    for (final f in foldersIn(id)) {
      await _deleteFolderRecursive(f.id, onDeleteList);
    }
    for (final l in listsIn(id)) {
      await onDeleteList(l.id);
      await _db.deleteList(l.id);
    }
    await _db.deleteFolder(id);
    _folders = _folders.where((f) => f.id != id).toList();
    _lists = _lists.where((l) => l.folderId != id).toList();
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
