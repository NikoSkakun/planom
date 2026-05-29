import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/contact.dart';
import '../notifications/notification_service.dart';

/// In-memory contact store + persistence for Birthdays-type lists. Mirrors
/// the `*Controller` pattern other domains use: load from DB into a
/// `ChangeNotifier`, mutate via async methods, call `notifyListeners` after
/// each mutation.
class ContactController with ChangeNotifier {
  ContactController(this._db);

  final DatabaseService _db;
  List<Contact> _contacts = [];
  List<Contact> _trashedContacts = [];

  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<Contact> get trashedContacts => List.unmodifiable(_trashedContacts);

  /// Active contacts that belong to [listId].
  List<Contact> contactsForList(String listId) {
    final scoped = _contacts.where((c) => c.listId == listId).toList()
      ..sort((a, b) => a.creationDate.compareTo(b.creationDate));
    return List.unmodifiable(scoped);
  }

  /// Contacts whose birth month + day match [date], regardless of year —
  /// drives calendar chips and day-sheet cards.
  List<Contact> contactsForDate(DateTime date) => _contacts
      .where((c) => c.birthMonth == date.month && c.birthDay == date.day)
      .toList();

  int countForList(String listId) =>
      _contacts.where((c) => c.listId == listId).length;

  Contact? contactById(String id) {
    for (final c in _contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    _contacts = await _db.getContacts();
    _trashedContacts = await _db.getTrashedContacts();
    notifyListeners();
  }

  Future<void> addContact(Contact contact) async {
    await _db.insertContact(contact);
    _contacts = [contact, ..._contacts];
    notifyListeners();
  }

  Future<void> updateContact(Contact updated) async {
    await _db.updateContact(updated);
    final i = _contacts.indexWhere((c) => c.id == updated.id);
    if (i == -1) return;
    _contacts = [..._contacts]..[i] = updated;
    notifyListeners();
  }

  Future<void> toggleCompleted(String id) async {
    final i = _contacts.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final original = _contacts[i];
    final completing = !original.isCompleted;
    final updated = original.copyWith(
      isCompleted: completing,
      completionDate: completing ? DateTime.now() : null,
      clearCompletionDate: !completing,
    );
    await _db.updateContact(updated);
    _contacts = [..._contacts]..[i] = updated;
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    final i = _contacts.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final now = DateTime.now();
    await _db.softDeleteContact(id, now);
    final trashed =
        _contacts[i].copyWith(isDeleted: true, deletedDate: now);
    _contacts = _contacts.where((c) => c.id != id).toList();
    _trashedContacts = [trashed, ..._trashedContacts];
    notifyListeners();
    NotificationService.instance.cancelTaskReminders(id);
  }

  Future<void> deleteContactsForList(String listId,
      [DateTime? deletedDate]) async {
    final now = deletedDate ?? DateTime.now();
    await _db.softDeleteContactsForList(listId, now);
    final toTrash = _contacts
        .where((c) => c.listId == listId)
        .map((c) => c.copyWith(isDeleted: true, deletedDate: now))
        .toList();
    _contacts = _contacts.where((c) => c.listId != listId).toList();
    _trashedContacts = [...toTrash, ..._trashedContacts];
    notifyListeners();
  }

  Future<void> restoreContact(String id, String? targetListId) async {
    final i = _trashedContacts.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final orig = _trashedContacts[i];
    final restored = orig.copyWith(
      listId: targetListId ?? orig.listId,
      isDeleted: false,
      clearDeletedDate: true,
    );
    await _db.restoreContact(id);
    if (targetListId != null && targetListId != orig.listId) {
      await _db.updateContact(restored);
    }
    _trashedContacts = List.of(_trashedContacts)..removeAt(i);
    _contacts = [restored, ..._contacts];
    notifyListeners();
  }

  /// Restores every contact soft-deleted at exactly [deletedDate]. Mirrors
  /// `TaskController.restoreAt` for bulk-restore flows (list trashed).
  Future<void> restoreAt(DateTime deletedDate) async {
    final ts = deletedDate.millisecondsSinceEpoch;
    final toRestore = _trashedContacts
        .where((c) => c.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    if (toRestore.isEmpty) return;
    for (final c in toRestore) {
      await _db.restoreContact(c.id);
    }
    final ids = toRestore.map((c) => c.id).toSet();
    _trashedContacts =
        _trashedContacts.where((c) => !ids.contains(c.id)).toList();
    _contacts = [
      ...toRestore.map(
          (c) => c.copyWith(isDeleted: false, clearDeletedDate: true)),
      ..._contacts,
    ];
    notifyListeners();
  }

  Future<void> permanentlyDeleteContact(String id) async {
    await _db.permanentlyDeleteContact(id);
    _trashedContacts =
        _trashedContacts.where((c) => c.id != id).toList();
    notifyListeners();
  }

  Future<void> permanentlyDeleteAllTrashed() async {
    await _db.clearTrashedContacts();
    _trashedContacts = [];
    notifyListeners();
  }
}
