import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import 'note_debug.dart';

class NoteController with ChangeNotifier {
  NoteController(this._db);

  final DatabaseService _db;
  List<NoteFolder> _folders = [];
  List<Note> _notes = [];
  List<NoteFolder> _trashedFolders = [];
  List<Note> _trashedNotes = [];

  List<NoteFolder> get trashedFolders => List.unmodifiable(_trashedFolders);
  List<Note> get trashedNotes => List.unmodifiable(_trashedNotes);

  /// Flat list of all non-trashed folders. Used by surfaces that need to
  /// enumerate every folder regardless of nesting (e.g. tab-bar shortcuts).
  List<NoteFolder> get folders => List.unmodifiable(_folders);

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

  NoteFolder? folderById(String id) {
    try {
      return _folders.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Note? noteById(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<Note> get allNotes => List.unmodifiable(_notes);

  Future<void> load() async {
    _folders = await _db.getNoteFolders();
    _notes = await _db.getNotes();
    _trashedFolders = await _db.getTrashedNoteFolders();
    _trashedNotes = await _db.getTrashedNotes();
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    noteDbg('CTRL.addNote id=${noteId(note.id)} '
        'c=${note.content.length} notesLen=${_notes.length}');
    final rowid = await _db.insertNote(note);
    _notes = [note, ..._notes];
    kNoteLastAdd = 'id=${noteId(note.id)} rowid=$rowid '
        'c=${note.content.length} len=${_notes.length}';
    noteDbg('CTRL.addNote done rowid=$rowid notesLen=${_notes.length}');
    notifyListeners();
  }

  Future<void> updateNote(Note updated) async {
    final rows = await _db.updateNote(updated);
    final i = _notes.indexWhere((n) => n.id == updated.id);
    kNoteLastUpd = 'id=${noteId(updated.id)} rows=$rows i=$i '
        'c=${updated.content.length} len=${_notes.length}';
    noteDbg('CTRL.updateNote id=${noteId(updated.id)} '
        'c=${updated.content.length} rows=$rows i=$i notesLen=${_notes.length}');
    if (i == -1) return;
    _notes = [..._notes]..[i] = updated;
    notifyListeners();
  }

  /// Moves a note to [targetFolderId] (or to the root when null). Preserves
  /// the modified-date stamp so re-parenting doesn't bump the note to the
  /// top of recently-edited lists.
  Future<void> moveNote(String noteId, String? targetFolderId) async {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i == -1) return;
    final orig = _notes[i];
    if (orig.folderId == targetFolderId) return;
    final updated = orig.copyWith(
      folderId: targetFolderId,
      clearFolderId: targetFolderId == null,
      preserveModifiedDate: true,
    );
    await _db.updateNote(updated);
    _notes = [..._notes]..[i] = updated;
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    final now = DateTime.now();
    await _db.softDeleteNote(id, now);
    final note = _notes.firstWhere((n) => n.id == id,
        orElse: () => Note(id: id, title: '', content: ''));
    _notes = _notes.where((n) => n.id != id).toList();
    _trashedNotes = [
      note.copyWith(
          isDeleted: true, deletedDate: now, preserveModifiedDate: true),
      ..._trashedNotes,
    ];
    notifyListeners();
  }

  Future<void> restoreNote(String id, String? targetFolderId) async {
    final i = _trashedNotes.indexWhere((n) => n.id == id);
    if (i == -1) return;
    final orig = _trashedNotes[i];
    final restored = Note(
      id: orig.id,
      title: orig.title,
      content: orig.content,
      folderId: targetFolderId,
      creationDate: orig.creationDate,
      modifiedDate: orig.modifiedDate,
      sortOrder: orig.sortOrder,
    );
    await _db.restoreNote(id);
    if (targetFolderId != orig.folderId) {
      await _db.updateNote(restored);
    }
    _trashedNotes = List.of(_trashedNotes)..removeAt(i);
    _notes = [..._notes, restored];
    notifyListeners();
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await _db.deleteNote(id);
    _trashedNotes = _trashedNotes.where((n) => n.id != id).toList();
    notifyListeners();
  }

  Future<void> addFolder(NoteFolder folder) async {
    await _db.insertNoteFolder(folder);
    _folders = [..._folders, folder];
    notifyListeners();
  }

  Future<void> updateFolder(NoteFolder folder) async {
    await _db.updateNoteFolder(folder);
    final idx = _folders.indexWhere((f) => f.id == folder.id);
    if (idx != -1) _folders[idx] = folder;
    notifyListeners();
  }

  Future<void> deleteFolder(String id) async {
    final now = DateTime.now();
    await _db.softDeleteNoteFolder(id, now);
    final folder = _folders.firstWhere((f) => f.id == id,
        orElse: () => NoteFolder(id: id, name: ''));
    _folders = _folders.where((f) => f.id != id).toList();
    _trashedFolders = [
      folder.copyWith(isDeleted: true, deletedDate: now),
      ..._trashedFolders,
    ];
    notifyListeners();
  }

  Future<void> restoreFolder(String id, String? targetParentId) async {
    final i = _trashedFolders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    final orig = _trashedFolders[i];
    final restored = NoteFolder(
      id: orig.id,
      name: orig.name,
      parentFolderId: targetParentId,
      creationDate: orig.creationDate,
      sortOrder: orig.sortOrder,
      iconId: orig.iconId,
    );
    await _db.restoreNoteFolder(id);
    if (targetParentId != orig.parentFolderId) {
      await _db.updateNoteFolder(restored);
    }
    _trashedFolders = List.of(_trashedFolders)..removeAt(i);
    _folders = [..._folders, restored];
    notifyListeners();
  }

  Future<void> permanentlyDeleteFolder(String id) async {
    await _db.deleteNoteFolder(id);
    _trashedFolders = _trashedFolders.where((f) => f.id != id).toList();
    notifyListeners();
  }

  Future<void> permanentlyDeleteAllTrashed() async {
    await _db.clearTrashedNotes();
    await _db.clearTrashedNoteFolders();
    _trashedNotes = [];
    _trashedFolders = [];
    notifyListeners();
  }

  /// Recursively soft-deletes a folder and all nested notes/folders. Returns
  /// the shared deletedDate so callers can pass it to [restoreAt] for undo.
  Future<DateTime> deleteFolderDeep(String id) async {
    final now = DateTime.now();
    await _softDeleteFolderRecursive(id, now);
    notifyListeners();
    return now;
  }

  /// Restores every note + note-folder soft-deleted at exactly [deletedDate].
  Future<void> restoreAt(DateTime deletedDate) async {
    final ts = deletedDate.millisecondsSinceEpoch;
    final notes = _trashedNotes
        .where((n) => n.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    final folders = _trashedFolders
        .where((f) => f.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    for (final f in folders) {
      await _db.restoreNoteFolder(f.id);
    }
    for (final n in notes) {
      await _db.restoreNote(n.id);
    }
    _trashedFolders = _trashedFolders
        .where((f) => f.deletedDate?.millisecondsSinceEpoch != ts)
        .toList();
    _trashedNotes = _trashedNotes
        .where((n) => n.deletedDate?.millisecondsSinceEpoch != ts)
        .toList();
    _folders = [
      ..._folders,
      ...folders.map((f) =>
          f.copyWith(isDeleted: false, clearDeletedDate: true)),
    ];
    _notes = [
      ..._notes,
      ...notes.map((n) => n.copyWith(
            isDeleted: false,
            clearDeletedDate: true,
            preserveModifiedDate: true,
          )),
    ];
    notifyListeners();
  }

  Future<void> _softDeleteFolderRecursive(
      String id, DateTime deletedDate) async {
    for (final f in foldersIn(id)) {
      await _softDeleteFolderRecursive(f.id, deletedDate);
    }
    for (final n in notesIn(id)) {
      await _db.softDeleteNote(n.id, deletedDate);
      _notes = _notes.where((x) => x.id != n.id).toList();
      _trashedNotes = [
        n.copyWith(
            isDeleted: true,
            deletedDate: deletedDate,
            preserveModifiedDate: true),
        ..._trashedNotes,
      ];
    }
    await _db.softDeleteNoteFolder(id, deletedDate);
    final folder = _folders.firstWhere((f) => f.id == id,
        orElse: () => NoteFolder(id: id, name: ''));
    _folders = _folders.where((f) => f.id != id).toList();
    _trashedFolders = [
      folder.copyWith(isDeleted: true, deletedDate: deletedDate),
      ..._trashedFolders,
    ];
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
    notifyListeners();
    await _db.updateNoteFolderSortOrders(scope);
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
      scope[i] = scope[i].copyWith(sortOrder: i + 1, preserveModifiedDate: true);
    }
    for (final updated in scope) {
      final idx = _notes.indexWhere((n) => n.id == updated.id);
      if (idx != -1) _notes[idx] = updated;
    }
    notifyListeners();
    await _db.updateNoteSortOrders(scope);
  }

  /// Long-press-drag insertion: move [movedId] to come right before
  /// [beforeId] within [parentFolderId]. Null [beforeId] = end of list.
  Future<void> reorderNoteFolderBefore({
    required String movedId,
    String? beforeId,
    required String? parentFolderId,
  }) async {
    final scope = _folders
        .where((f) =>
            f.parentFolderId == parentFolderId && f.id != movedId)
        .toList();
    _sortFoldersByDefault(scope);

    final moved = _folders.firstWhere((f) => f.id == movedId,
        orElse: () => NoteFolder(id: movedId, name: ''));
    if (moved.name.isEmpty &&
        _folders.indexWhere((f) => f.id == movedId) == -1) return;

    int insertAt = beforeId == null
        ? scope.length
        : scope.indexWhere((f) => f.id == beforeId);
    if (insertAt < 0) insertAt = scope.length;
    scope.insert(insertAt, moved);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i].copyWith(sortOrder: i + 1);
    }
    for (final updated in scope) {
      final idx = _folders.indexWhere((f) => f.id == updated.id);
      if (idx != -1) _folders[idx] = updated;
    }
    notifyListeners();
    await _db.updateNoteFolderSortOrders(scope);
  }

  /// Same as [reorderNoteFolderBefore] but for note rows. Preserves
  /// modifiedDate so reordering doesn't bump notes to the top.
  Future<void> reorderNoteBefore({
    required String movedId,
    String? beforeId,
    required String? folderId,
  }) async {
    final scope = _notes
        .where((n) => n.folderId == folderId && n.id != movedId)
        .toList();
    _sortNotesByDefault(scope);

    final moved = _notes.firstWhere((n) => n.id == movedId,
        orElse: () => Note(id: movedId, title: '', content: ''));
    if (moved.title.isEmpty &&
        moved.content.isEmpty &&
        _notes.indexWhere((n) => n.id == movedId) == -1) return;

    int insertAt = beforeId == null
        ? scope.length
        : scope.indexWhere((n) => n.id == beforeId);
    if (insertAt < 0) insertAt = scope.length;
    scope.insert(insertAt, moved);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i]
          .copyWith(sortOrder: i + 1, preserveModifiedDate: true);
    }
    for (final updated in scope) {
      final idx = _notes.indexWhere((n) => n.id == updated.id);
      if (idx != -1) _notes[idx] = updated;
    }
    notifyListeners();
    await _db.updateNoteSortOrders(scope);
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
