import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/contacts/contact_controller.dart';
import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/contact.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late ContactController controller;

  setUp(() async {
    db = freshDb();
    controller = ContactController(db);
    await controller.load();
  });

  group('CRUD', () {
    test('addContact then contactById / contacts getter', () async {
      final c = Contact(
        name: 'Alice',
        listId: 'list-1',
        birthMonth: 3,
        birthDay: 14,
      );
      await controller.addContact(c);

      expect(controller.contacts.length, 1);
      expect(controller.contactById(c.id)?.name, 'Alice');
      expect(controller.contactById('nope'), isNull);
    });

    test('addContact persists across reload', () async {
      final c = Contact(
        name: 'Bob',
        listId: 'list-1',
        birthMonth: 6,
        birthDay: 1,
        birthYear: 1990,
      );
      await controller.addContact(c);

      final fresh = ContactController(db);
      await fresh.load();
      expect(fresh.contacts.length, 1);
      expect(fresh.contactById(c.id)?.birthYear, 1990);
    });

    test('updateContact mutates the stored record', () async {
      final c = Contact(
        name: 'Carol',
        listId: 'list-1',
        birthMonth: 2,
        birthDay: 2,
      );
      await controller.addContact(c);
      await controller.updateContact(c.copyWith(name: 'Caroline'));
      expect(controller.contactById(c.id)?.name, 'Caroline');
    });

    test('contactsForList sorted by creationDate, countForList', () async {
      final older = Contact(
        name: 'Older',
        listId: 'list-1',
        birthMonth: 1,
        birthDay: 1,
        creationDate: DateTime(2020, 1, 1),
      );
      final newer = Contact(
        name: 'Newer',
        listId: 'list-1',
        birthMonth: 1,
        birthDay: 1,
        creationDate: DateTime(2024, 1, 1),
      );
      final other = Contact(
        name: 'Other',
        listId: 'list-2',
        birthMonth: 1,
        birthDay: 1,
      );
      // Add newer first to verify sort actually reorders.
      await controller.addContact(newer);
      await controller.addContact(older);
      await controller.addContact(other);

      final scoped = controller.contactsForList('list-1');
      expect(scoped.map((c) => c.name).toList(), ['Older', 'Newer']);
      expect(controller.countForList('list-1'), 2);
      expect(controller.countForList('list-2'), 1);
      expect(controller.countForList('missing'), 0);
    });
  });

  group('contactsForDate', () {
    test('matches month+day ignoring year', () async {
      final date = DateTime(2026, 7, 20);
      final match = Contact(
        name: 'BornDifferentYear',
        listId: 'list-1',
        birthMonth: 7,
        birthDay: 20,
        birthYear: 1985, // different year from the queried date
      );
      final noMatch = Contact(
        name: 'WrongDay',
        listId: 'list-1',
        birthMonth: 7,
        birthDay: 21,
      );
      await controller.addContact(match);
      await controller.addContact(noMatch);

      final hits = controller.contactsForDate(date);
      expect(hits.length, 1);
      expect(hits.single.name, 'BornDifferentYear');
    });

    test('Feb 29 contact matches a Feb 29 date', () async {
      final leapContact = Contact(
        name: 'LeapBaby',
        listId: 'list-1',
        birthMonth: 2,
        birthDay: 29,
      );
      await controller.addContact(leapContact);

      // 2024 is a leap year -> Feb 29 exists.
      final hits = controller.contactsForDate(DateTime(2024, 2, 29));
      expect(hits.map((c) => c.name), contains('LeapBaby'));
    });
  });

  group('toggleCompleted', () {
    test('flips isCompleted and sets/clears completionDate', () async {
      final c = Contact(
        name: 'Dan',
        listId: 'list-1',
        birthMonth: 4,
        birthDay: 4,
        isCompletable: true,
      );
      await controller.addContact(c);

      await controller.toggleCompleted(c.id);
      var stored = controller.contactById(c.id)!;
      expect(stored.isCompleted, isTrue);
      expect(stored.completionDate, isNotNull);

      await controller.toggleCompleted(c.id);
      stored = controller.contactById(c.id)!;
      expect(stored.isCompleted, isFalse);
      expect(stored.completionDate, isNull);
    });
  });

  group('soft delete / restore / trash', () {
    test('deleteContact moves to trashedContacts', () async {
      final c = Contact(
        name: 'Eve',
        listId: 'list-1',
        birthMonth: 5,
        birthDay: 5,
      );
      await controller.addContact(c);
      await controller.deleteContact(c.id);

      expect(controller.contacts, isEmpty);
      expect(controller.trashedContacts.length, 1);
      expect(controller.trashedContacts.single.isDeleted, isTrue);
      expect(controller.trashedContacts.single.deletedDate, isNotNull);
    });

    test('restoreContact returns contact to active, can retarget list',
        () async {
      final c = Contact(
        name: 'Frank',
        listId: 'list-1',
        birthMonth: 6,
        birthDay: 6,
      );
      await controller.addContact(c);
      await controller.deleteContact(c.id);

      await controller.restoreContact(c.id, 'list-2');
      expect(controller.trashedContacts, isEmpty);
      expect(controller.contacts.length, 1);
      final restored = controller.contactById(c.id)!;
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedDate, isNull);
      expect(restored.listId, 'list-2');

      // Persisted retarget survives reload.
      final fresh = ContactController(db);
      await fresh.load();
      expect(fresh.contactById(c.id)?.listId, 'list-2');
    });

    test('restoreAt restores everything trashed at the same timestamp',
        () async {
      final a = Contact(
          name: 'A', listId: 'list-1', birthMonth: 1, birthDay: 1);
      final b = Contact(
          name: 'B', listId: 'list-1', birthMonth: 2, birthDay: 2);
      await controller.addContact(a);
      await controller.addContact(b);

      // deleteContactsForList shares one deletedDate across the batch.
      final ts = DateTime(2026, 5, 31, 12, 0, 0);
      await controller.deleteContactsForList('list-1', ts);
      expect(controller.contacts, isEmpty);
      expect(controller.trashedContacts.length, 2);

      await controller.restoreAt(ts);
      expect(controller.trashedContacts, isEmpty);
      expect(controller.contacts.length, 2);
    });

    test('permanentlyDeleteContact removes from trash only', () async {
      final c = Contact(
          name: 'Gus', listId: 'list-1', birthMonth: 7, birthDay: 7);
      await controller.addContact(c);
      await controller.deleteContact(c.id);

      await controller.permanentlyDeleteContact(c.id);
      expect(controller.trashedContacts, isEmpty);

      final fresh = ContactController(db);
      await fresh.load();
      expect(fresh.contacts, isEmpty);
      expect(fresh.trashedContacts, isEmpty);
    });

    test('permanentlyDeleteAllTrashed clears all trashed', () async {
      final a = Contact(
          name: 'A', listId: 'list-1', birthMonth: 1, birthDay: 1);
      final b = Contact(
          name: 'B', listId: 'list-1', birthMonth: 2, birthDay: 2);
      await controller.addContact(a);
      await controller.addContact(b);
      await controller.deleteContact(a.id);
      await controller.deleteContact(b.id);
      expect(controller.trashedContacts.length, 2);

      await controller.permanentlyDeleteAllTrashed();
      expect(controller.trashedContacts, isEmpty);
    });

    test('deleteContactsForList soft-deletes every contact in the list',
        () async {
      final a = Contact(
          name: 'A', listId: 'list-1', birthMonth: 1, birthDay: 1);
      final b = Contact(
          name: 'B', listId: 'list-2', birthMonth: 2, birthDay: 2);
      await controller.addContact(a);
      await controller.addContact(b);

      await controller.deleteContactsForList('list-1');
      expect(controller.contacts.map((c) => c.name), ['B']);
      expect(controller.trashedContacts.map((c) => c.name), ['A']);
    });
  });
}
