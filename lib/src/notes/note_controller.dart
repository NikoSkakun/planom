import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/note.dart';
import '../models/note_folder.dart';

class NoteController with ChangeNotifier {
  NoteController(this._db);

  final DatabaseService _db;
  List<NoteFolder> _folders = [];
  List<Note> _notes = [];

  List<NoteFolder> foldersIn(String? parentId) =>
      _folders.where((f) => f.parentFolderId == parentId).toList();

  List<Note> notesIn(String? folderId) =>
      _notes.where((n) => n.folderId == folderId).toList();

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
    // Re-sort by modifiedDate DESC so the updated note floats to the top.
    _notes.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
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
}
