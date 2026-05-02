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

  List<AppFolder> foldersIn(String? parentId) =>
      _folders.where((f) => f.parentFolderId == parentId).toList();

  List<AppList> listsIn(String? folderId) =>
      _lists.where((l) => l.folderId == folderId).toList();

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

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    _folders = _folders.where((f) => f.id != id).toList();
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    await _db.deleteList(id);
    _lists = _lists.where((l) => l.id != id).toList();
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
}
