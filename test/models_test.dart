import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/models/app_folder.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/models/contact.dart';
import 'package:planom/src/models/event.dart';
import 'package:planom/src/models/list_section.dart';
import 'package:planom/src/models/list_type.dart';
import 'package:planom/src/models/note.dart';
import 'package:planom/src/models/note_folder.dart';
import 'package:planom/src/models/recurrence.dart';
import 'package:planom/src/models/routine.dart';
import 'package:planom/src/models/routine_entry.dart';
import 'package:planom/src/models/routine_reminder.dart';
import 'package:planom/src/models/tag.dart';
import 'package:planom/src/models/task.dart';

void main() {
  group('Task', () {
    test('auto-generates id and defaults', () {
      final t = Task(title: 'A');
      expect(t.id, isNotEmpty);
      expect(t.iconId, 'inbox');
      expect(t.isCompleted, isFalse);
      expect(t.priority, 0);
      expect(t.reminderOffsets, isEmpty);
      expect(t.tagIds, isEmpty);
    });

    test('toMap/fromMap round-trips all fields', () {
      final t = Task(
        title: 'Buy milk',
        note: 'note body',
        isCompleted: true,
        dueDate: DateTime(2026, 5, 31),
        doTime: 600,
        duration: 45,
        listId: 'list1',
        priority: 3,
        sortOrder: 7,
        completionDate: DateTime(2026, 5, 30),
        reminderOffsets: const [-10, -60],
        parentTaskId: 'parent1',
        tagIds: const ['t1', 't2'],
        recurrence: '{"type":"daily","interval":1}',
        sectionId: 'sec1',
      );
      final back = Task.fromMap(t.toMap());
      expect(back.id, t.id);
      expect(back.title, 'Buy milk');
      expect(back.note, 'note body');
      expect(back.isCompleted, isTrue);
      expect(back.dueDate, DateTime(2026, 5, 31));
      expect(back.doTime, 600);
      expect(back.duration, 45);
      expect(back.listId, 'list1');
      expect(back.priority, 3);
      expect(back.sortOrder, 7);
      expect(back.completionDate, DateTime(2026, 5, 30));
      expect(back.reminderOffsets, const [-10, -60]);
      expect(back.parentTaskId, 'parent1');
      expect(back.tagIds, const ['t1', 't2']);
      expect(back.recurrence, '{"type":"daily","interval":1}');
      expect(back.sectionId, 'sec1');
    });

    test('empty reminderOffsets/tagIds survive round-trip', () {
      final back = Task.fromMap(Task(title: 'x').toMap());
      expect(back.reminderOffsets, isEmpty);
      expect(back.tagIds, isEmpty);
    });

    test('copyWith clear flags null out fields', () {
      final t = Task(
        title: 'x',
        note: 'n',
        dueDate: DateTime(2026, 1, 1),
        doTime: 60,
        duration: 30,
        listId: 'l',
        completionDate: DateTime(2026, 1, 1),
        parentTaskId: 'p',
        recurrence: 'r',
        sectionId: 's',
        deletedDate: DateTime(2026, 1, 1),
      );
      final c = t.copyWith(
        clearNote: true,
        clearDueDate: true,
        clearDoTime: true,
        clearDuration: true,
        clearListId: true,
        clearCompletionDate: true,
        clearParentTaskId: true,
        clearRecurrence: true,
        clearSectionId: true,
        clearDeletedDate: true,
      );
      expect(c.note, isNull);
      expect(c.dueDate, isNull);
      expect(c.doTime, isNull);
      expect(c.duration, isNull);
      expect(c.listId, isNull);
      expect(c.completionDate, isNull);
      expect(c.parentTaskId, isNull);
      expect(c.recurrence, isNull);
      expect(c.sectionId, isNull);
      expect(c.deletedDate, isNull);
      // Identity / untouched fields preserved.
      expect(c.id, t.id);
      expect(c.title, 'x');
    });

    test('copyWith without clear keeps existing note even if note: null', () {
      final t = Task(title: 'x', note: 'keep');
      expect(t.copyWith(note: null).note, 'keep');
      expect(t.copyWith(title: 'y').note, 'keep');
    });
  });

  group('Note', () {
    test('round-trips and defaults', () {
      final n = Note(title: 'T', content: 'C', folderId: 'f', sortOrder: 2);
      final back = Note.fromMap(n.toMap());
      expect(back.id, n.id);
      expect(back.title, 'T');
      expect(back.content, 'C');
      expect(back.folderId, 'f');
      expect(back.sortOrder, 2);
      expect(back.isDeleted, isFalse);
    });

    test('copyWith bumps modifiedDate unless preserved', () async {
      final n = Note(
        title: 'T',
        content: 'C',
        modifiedDate: DateTime(2020, 1, 1),
      );
      final preserved = n.copyWith(content: 'C2', preserveModifiedDate: true);
      expect(preserved.modifiedDate, DateTime(2020, 1, 1));
      final bumped = n.copyWith(content: 'C3');
      expect(bumped.modifiedDate.isAfter(DateTime(2020, 1, 1)), isTrue);
    });

    test('clearFolderId nulls the folder', () {
      final n = Note(title: 'T', content: 'C', folderId: 'f');
      expect(n.copyWith(clearFolderId: true).folderId, isNull);
    });
  });

  group('Recurrence', () {
    test('parse null/empty/garbage returns null', () {
      expect(Recurrence.parse(null), isNull);
      expect(Recurrence.parse(''), isNull);
      expect(Recurrence.parse('not json'), isNull);
    });

    test('toJson/parse round-trip', () {
      const r = Recurrence(
        type: RecurrenceType.weekly,
        interval: 2,
        weekdays: [0, 2, 4],
      );
      final parsed = Recurrence.parse(r.toJson())!;
      expect(parsed.type, RecurrenceType.weekly);
      expect(parsed.interval, 2);
      expect(parsed.weekdays, [0, 2, 4]);
    });

    test('daily nextAfter advances by interval days', () {
      const r = Recurrence(type: RecurrenceType.daily, interval: 3);
      expect(r.nextAfter(DateTime(2026, 1, 10)), DateTime(2026, 1, 13));
    });

    test('weekly with no weekdays advances by interval weeks', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2);
      expect(r.nextAfter(DateTime(2026, 1, 1)), DateTime(2026, 1, 15));
    });

    test('monthly clamps to shorter month (Jan 31 -> Feb)', () {
      const r = Recurrence(type: RecurrenceType.monthly, interval: 1);
      // 2024 is a leap year -> Feb 29; 2023 -> Feb 28.
      expect(r.nextAfter(DateTime(2024, 1, 31)), DateTime(2024, 2, 29));
      expect(r.nextAfter(DateTime(2023, 1, 31)), DateTime(2023, 2, 28));
    });

    test('monthly carries the year when crossing December', () {
      const r = Recurrence(type: RecurrenceType.monthly, interval: 2);
      expect(r.nextAfter(DateTime(2026, 11, 15)), DateTime(2027, 1, 15));
    });

    test('yearly advances by interval years', () {
      const r = Recurrence(type: RecurrenceType.yearly, interval: 1);
      expect(r.nextAfter(DateTime(2026, 6, 1)), DateTime(2027, 6, 1));
    });

    test('unknown type falls back to daily', () {
      final r = Recurrence.parse('{"type":"hourly","interval":1}');
      expect(r, isNotNull);
      expect(r!.type, RecurrenceType.daily);
    });
  });

  group('Routine', () {
    test('round-trips certain_amount fields', () {
      final r = Routine(
        name: 'Water',
        goalType: 'certain_amount',
        goalAmount: 8,
        goalUnit: 'cup',
        recordAmount: 1,
      );
      final back = Routine.fromMap(r.toMap());
      expect(back.name, 'Water');
      expect(back.goalType, 'certain_amount');
      expect(back.goalAmount, 8);
      expect(back.goalUnit, 'cup');
      expect(back.recordAmount, 1);
      expect(back.frequencyType, 'daily');
    });

    test('frequencyType defaults to daily when absent in map', () {
      final r = Routine(name: 'R', goalType: 'achieve_all');
      final map = r.toMap()..remove('frequencyType');
      final back = Routine.fromMap(map);
      expect(back.frequencyType, 'daily');
    });

    test('round-trips specific_days weekdays', () {
      final r = Routine(
        name: 'Gym',
        goalType: 'achieve_all',
        frequencyType: 'specific_days',
        weekdays: const [0, 2, 4],
      );
      final back = Routine.fromMap(r.toMap());
      expect(back.frequencyType, 'specific_days');
      expect(back.weekdays, const [0, 2, 4]);
    });

    test('daily routine has null weekdays (no parse crash)', () {
      final r = Routine(name: 'R', goalType: 'achieve_all');
      final back = Routine.fromMap(r.toMap());
      expect(back.weekdays, isNull);
    });

    test('copyWith clear flags', () {
      final r = Routine(
        name: 'R',
        goalType: 'certain_amount',
        goalAmount: 5,
        goalUnit: 'x',
        recordAmount: 2,
        frequencyType: 'specific_days',
        weekdays: const [1, 3],
      );
      final c = r.copyWith(
        clearGoalAmount: true,
        clearGoalUnit: true,
        clearRecordAmount: true,
        clearWeekdays: true,
      );
      expect(c.goalAmount, isNull);
      expect(c.goalUnit, isNull);
      expect(c.recordAmount, isNull);
      expect(c.weekdays, isNull);
    });

    test('preserves a custom photo iconId', () {
      final r = Routine(
        name: 'Yoga',
        goalType: 'achieve_all',
        iconId: 'icons/1234.png',
      );
      final back = Routine.fromMap(r.toMap());
      expect(back.iconId, 'icons/1234.png');
    });

    test('round-trips interval, start date, wait flag and reminders', () {
      final r = Routine(
        name: 'Clean',
        goalType: 'achieve_all',
        frequencyType: 'interval',
        intervalDays: 3,
        waitForCompletion: true,
        startDate: DateTime(2026, 5, 10),
        reminders: const [
          RoutineReminder.time(540),
          RoutineReminder.spread(startMinute: 480, every: 120),
          RoutineReminder.afterEach(90),
        ],
      );
      final back = Routine.fromMap(r.toMap());
      expect(back.frequencyType, 'interval');
      expect(back.intervalDays, 3);
      expect(back.waitForCompletion, isTrue);
      expect(back.startDate, DateTime(2026, 5, 10));
      expect(back.reminders.length, 3);
      expect(back.reminders[0].type, RoutineReminder.typeTime);
      expect(back.reminders[0].value, 540);
      expect(back.reminders[1].type, RoutineReminder.typeSpread);
      expect(back.reminders[1].interval, 120);
      expect(back.reminders[2], const RoutineReminder.afterEach(90));
    });

    test('legacy map without new fields defaults safely', () {
      final r = Routine(name: 'R', goalType: 'achieve_all');
      final map = r.toMap()
        ..remove('startDate')
        ..remove('intervalDays')
        ..remove('waitForCompletion')
        ..remove('reminders');
      final back = Routine.fromMap(map);
      expect(back.startDate, isNull);
      expect(back.intervalDays, isNull);
      expect(back.waitForCompletion, isFalse);
      expect(back.reminders, isEmpty);
    });
  });

  group('RoutineReminder', () {
    test('encode/decode round-trip', () {
      const list = [
        RoutineReminder.time(600),
        RoutineReminder.spread(startMinute: 480, every: 90),
        RoutineReminder.afterEach(120),
      ];
      final back = RoutineReminder.decode(RoutineReminder.encode(list));
      expect(back, list);
    });

    test('decode tolerates null/garbage', () {
      expect(RoutineReminder.decode(null), isEmpty);
      expect(RoutineReminder.decode(''), isEmpty);
      expect(RoutineReminder.decode('not json'), isEmpty);
    });
  });

  group('Contact', () {
    test('round-trips', () {
      final c = Contact(
        name: 'Mum',
        listId: 'birthdays',
        birthMonth: 2,
        birthDay: 29,
        birthYear: 1980,
        isCompletable: true,
        reminderOffsets: const [-1440],
      );
      final back = Contact.fromMap(c.toMap());
      expect(back.name, 'Mum');
      expect(back.listId, 'birthdays');
      expect(back.birthMonth, 2);
      expect(back.birthDay, 29);
      expect(back.birthYear, 1980);
      expect(back.isCompletable, isTrue);
      expect(back.reminderOffsets, const [-1440]);
    });

    test('clearBirthYear / clearNote', () {
      final c = Contact(
        name: 'X',
        note: 'n',
        listId: 'l',
        birthMonth: 1,
        birthDay: 1,
        birthYear: 2000,
      );
      final cleared = c.copyWith(clearBirthYear: true, clearNote: true);
      expect(cleared.birthYear, isNull);
      expect(cleared.note, isNull);
    });
  });

  group('Event', () {
    test('round-trips', () {
      final e = Event(
        title: 'Meeting',
        note: 'agenda',
        date: DateTime(2026, 5, 31),
        doTime: 540,
        duration: 60,
        reminderOffsets: const [-15],
      );
      final back = Event.fromMap(e.toMap());
      expect(back.title, 'Meeting');
      expect(back.note, 'agenda');
      expect(back.date, DateTime(2026, 5, 31));
      expect(back.doTime, 540);
      expect(back.duration, 60);
      expect(back.reminderOffsets, const [-15]);
    });

    test('clear flags', () {
      final e = Event(
        title: 'X',
        note: 'n',
        date: DateTime(2026, 1, 1),
        doTime: 100,
        duration: 30,
      );
      final c = e.copyWith(clearNote: true, clearDoTime: true, clearDuration: true);
      expect(c.note, isNull);
      expect(c.doTime, isNull);
      expect(c.duration, isNull);
    });
  });

  group('Tag', () {
    test('round-trips and clearColor', () {
      final t = Tag(name: 'urgent', color: 0xFFFF0000);
      final back = Tag.fromMap(t.toMap());
      expect(back.name, 'urgent');
      expect(back.color, 0xFFFF0000);
      expect(t.copyWith(clearColor: true).color, isNull);
    });
  });

  group('AppFolder / AppList / NoteFolder', () {
    test('AppFolder round-trip + clears', () {
      final f = AppFolder(
        name: 'Work',
        parentFolderId: 'p',
        iconId: 'star',
        iconColor: 0xFF00FF00,
      );
      final back = AppFolder.fromMap(f.toMap());
      expect(back.name, 'Work');
      expect(back.parentFolderId, 'p');
      expect(back.iconId, 'star');
      expect(back.iconColor, 0xFF00FF00);
      final c = f.copyWith(clearParent: true, clearIconId: true, clearIconColor: true);
      expect(c.parentFolderId, isNull);
      expect(c.iconId, isNull);
      expect(c.iconColor, isNull);
    });

    test('AppList round-trip carries listType', () {
      final l = AppList(name: 'Groceries', listType: ListType.shopping, color: 0xFF112233);
      final back = AppList.fromMap(l.toMap());
      expect(back.name, 'Groceries');
      expect(back.listType, ListType.shopping);
      expect(back.color, 0xFF112233);
      expect(l.copyWith(clearColor: true).color, isNull);
    });

    test('NoteFolder round-trip', () {
      final nf = NoteFolder(name: 'Ideas', iconId: 'lightbulb');
      final back = NoteFolder.fromMap(nf.toMap());
      expect(back.name, 'Ideas');
      expect(back.iconId, 'lightbulb');
    });
  });

  group('ListType', () {
    test('fromString maps known values and falls back', () {
      expect(ListType.fromString('tasks'), ListType.tasks);
      expect(ListType.fromString('birthdays'), ListType.birthdays);
      expect(ListType.fromString('shopping'), ListType.shopping);
      expect(ListType.fromString('???'), ListType.tasks);
      expect(ListType.fromString(null), ListType.tasks);
    });
  });

  group('ListSection / RoutineEntry', () {
    test('ListSection round-trip', () {
      final s = ListSection(listId: 'l', name: 'Today', sortOrder: 1, isCollapsed: true);
      final back = ListSection.fromMap(s.toMap());
      expect(back.listId, 'l');
      expect(back.name, 'Today');
      expect(back.sortOrder, 1);
      expect(back.isCollapsed, isTrue);
    });

    test('RoutineEntry round-trip + copyWith amount', () {
      final e = RoutineEntry(routineId: 'r', date: DateTime(2026, 5, 31), amount: 3);
      final back = RoutineEntry.fromMap(e.toMap());
      expect(back.routineId, 'r');
      expect(back.date, DateTime(2026, 5, 31));
      expect(back.amount, 3);
      expect(e.copyWith(amount: 9).amount, 9);
    });
  });
}
