import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/note.dart';
import '../models/note_folder.dart';

class NoteController with ChangeNotifier {
  NoteController(this._db);

  final DatabaseService _db;
  List<NoteFolder> _folders = [];
  List<Note> _notes = [];

  List<NoteFolder> foldersIn(String? parentId) {
    final result =
        _folders.where((f) => f.parentFolderId == parentId).toList();
    _sortFoldersByDefault(result);
    return result;
  }

  List<Note> notesIn(String? folderId) {
    final result = _notes.where((n) => n.folderId == folderId).toList();
    _sortNotesByDefault(result);
    return result;
  }

  Future<void> load() async {
    _folders = await _db.getNoteFolders();
    _notes = await _db.getNotes();
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    await _db.insertNote(note);
    _notes = [note, ..._notes];
    notifyListeners();
  }

  Future<void> updateNote(Note updated) async {
    await _db.updateNote(updated);
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i == -1) return;
    _notes = [..._notes]..[i] = updated;
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _db.deleteNote(id);
    _notes = _notes.where((n) => n.id != id).toList();
    notifyListeners();
  }

  Future<void> addFolder(NoteFolder folder) async {
    await _db.insertNoteFolder(folder);
    _folders = [..._folders, folder];
    notifyListeners();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteNoteFolder(id);
    _folders = _folders.where((f) => f.id != id).toList();
    notifyListeners();
  }

  Future<void> deleteFolderDeep(String id) async {
    await _deleteFolderRecursive(id);
    notifyListeners();
  }

  Future<void> _deleteFolderRecursive(String id) async {
    for (final f in foldersIn(id)) {
      await _deleteFolderRecursive(f.id);
    }
    await _db.deleteNotesForFolder(id);
    await _db.deleteNoteFolder(id);
    _folders = _folders.where((f) => f.id != id).toList();
    _notes = _notes.where((n) => n.folderId != id).toList();
  }

  /// Reorders note folders within [parentFolderId] scope.
  Future<void> reorderNoteFolders(
      String? parentFolderId, int oldIndex, int newIndex) async {
    final scope = _folders
        .where((f) => f.parentFolderId == parentFolderId)
        .toList();
    _sortFoldersByDefault(scope);

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
    await _db.updateNoteFolderSortOrders(scope);
    notifyListeners();
  }

  /// Reorders notes within [folderId] scope.
  Future<void> reorderNotes(
      String? folderId, int oldIndex, int newIndex) async {
    final scope = _notes.where((n) => n.folderId == folderId).toList();
    _sortNotesByDefault(scope);

    if (newIndex > oldIndex) newIndex--;
    final item = scope.removeAt(oldIndex);
    scope.insert(newIndex, item);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i].copyWith(sortOrder: i + 1);
    }
    for (final updated in scope) {
      final idx = _notes.indexWhere((n) => n.id == updated.id);
      if (idx != -1) _notes[idx] = updated;
    }
    await _db.updateNoteSortOrders(scope);
    notifyListeners();
  }

  static void _sortFoldersByDefault(List<NoteFolder> list) {
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.creationDate.compareTo(b.creationDate);
    });
  }

  static void _sortNotesByDefault(List<Note> list) {
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return b.modifiedDate.compareTo(a.modifiedDate);
    });
  }
}
