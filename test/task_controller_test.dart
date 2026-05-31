import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/recurrence.dart';
import 'package:planom/src/models/task.dart';
import 'package:planom/src/tasks/task_controller.dart';

import 'support/test_db.dart';

/// Builds a controller bound to [db] and loads it.
Future<TaskController> loadedController(DatabaseService db) async {
  final c = TaskController(db);
  await c.load();
  return c;
}

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late TaskController controller;

  setUp(() async {
    db = freshDb();
    controller = await loadedController(db);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  // ── add / update / taskById ──────────────────────────────────────────────

  group('addTask / updateTask / taskById', () {
    test('addTask makes an inbox task appear and findable by id', () async {
      final t = Task(title: 'Buy milk');
      await controller.addTask(t);

      expect(controller.taskById(t.id)?.title, 'Buy milk');
      expect(controller.inboxTasks.map((x) => x.id), contains(t.id));
      expect(controller.allTasks.map((x) => x.id), contains(t.id));
    });

    test('addTask persists to the DB (survives reload)', () async {
      final t = Task(title: 'Persisted');
      await controller.addTask(t);

      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.taskById(t.id)?.title, 'Persisted');
    });

    test('updateTask changes fields and persists', () async {
      final t = Task(title: 'Original');
      await controller.addTask(t);

      await controller.updateTask(t.copyWith(title: 'Renamed'));
      expect(controller.taskById(t.id)?.title, 'Renamed');

      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.taskById(t.id)?.title, 'Renamed');
    });

    test('taskById returns null for unknown id', () {
      expect(controller.taskById('nope'), isNull);
    });
  });

  // ── Smart lists ──────────────────────────────────────────────────────────

  group('smart lists', () {
    test('inboxTasks = active tasks with listId == null', () async {
      final inbox = Task(title: 'Inbox');
      final listed = Task(title: 'Listed', listId: 'list1');
      await controller.addTask(inbox);
      await controller.addTask(listed);

      final ids = controller.inboxTasks.map((t) => t.id).toList();
      expect(ids, contains(inbox.id));
      expect(ids, isNot(contains(listed.id)));
    });

    test('todayTasks includes due-today and overdue-incomplete', () async {
      final dueToday = Task(title: 'today', dueDate: today());
      final overdue =
          Task(title: 'overdue', dueDate: today().subtract(const Duration(days: 1)));
      final future =
          Task(title: 'future', dueDate: today().add(const Duration(days: 3)));
      await controller.addTask(dueToday);
      await controller.addTask(overdue);
      await controller.addTask(future);

      final ids = controller.todayTasks.map((t) => t.id).toList();
      expect(ids, contains(dueToday.id));
      expect(ids, contains(overdue.id), reason: 'overdue rolls into today');
      expect(ids, isNot(contains(future.id)));
    });

    test('overdue but completed does NOT appear in todayTasks', () async {
      final overdue =
          Task(title: 'overdue', dueDate: today().subtract(const Duration(days: 2)));
      await controller.addTask(overdue);
      await controller.toggleCompleted(overdue.id);

      expect(controller.todayTasks.map((t) => t.id), isNot(contains(overdue.id)));
    });

    test('tomorrowTasks = dueDate exactly tomorrow', () async {
      final tomorrow =
          Task(title: 'tom', dueDate: today().add(const Duration(days: 1)));
      final dayAfter =
          Task(title: 'dayAfter', dueDate: today().add(const Duration(days: 2)));
      final dueToday = Task(title: 'today', dueDate: today());
      await controller.addTask(tomorrow);
      await controller.addTask(dayAfter);
      await controller.addTask(dueToday);

      final ids = controller.tomorrowTasks.map((t) => t.id).toList();
      expect(ids, [tomorrow.id]);
    });

    test('upcomingTasks = dueDate after today', () async {
      final dueToday = Task(title: 'today', dueDate: today());
      final tomorrow =
          Task(title: 'tom', dueDate: today().add(const Duration(days: 1)));
      final later =
          Task(title: 'later', dueDate: today().add(const Duration(days: 5)));
      await controller.addTask(dueToday);
      await controller.addTask(tomorrow);
      await controller.addTask(later);

      final ids = controller.upcomingTasks.map((t) => t.id).toList();
      expect(ids, isNot(contains(dueToday.id)));
      expect(ids, contains(tomorrow.id));
      expect(ids, contains(later.id));
      // Sorted ascending by date.
      expect(ids, [tomorrow.id, later.id]);
    });

    test('tasksForList / completedTasksForList', () async {
      final a = Task(title: 'a', listId: 'L');
      final b = Task(title: 'b', listId: 'L');
      final other = Task(title: 'other', listId: 'OTHER');
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.addTask(other);
      await controller.toggleCompleted(b.id);

      final forL = controller.tasksForList('L').map((t) => t.id).toList();
      expect(forL.toSet(), {a.id, b.id});
      expect(forL, isNot(contains(other.id)));

      final completed = controller.completedTasksForList('L').map((t) => t.id);
      expect(completed, [b.id]);
    });

    test('tasksForListSection filters by section and excludes completed', () async {
      final inDefault = Task(title: 'def', listId: 'L');
      final inSec = Task(title: 'sec', listId: 'L', sectionId: 'S1');
      final completedInSec =
          Task(title: 'done', listId: 'L', sectionId: 'S1');
      await controller.addTask(inDefault);
      await controller.addTask(inSec);
      await controller.addTask(completedInSec);
      await controller.toggleCompleted(completedInSec.id);

      expect(controller.tasksForListSection('L', null).map((t) => t.id),
          [inDefault.id]);
      expect(controller.tasksForListSection('L', 'S1').map((t) => t.id),
          [inSec.id]);
    });

    test('tasksForDate matches by year/month/day', () async {
      final d = today().add(const Duration(days: 4));
      final onDate = Task(title: 'onDate', dueDate: d.add(const Duration(hours: 9)));
      final offDate =
          Task(title: 'off', dueDate: d.add(const Duration(days: 1)));
      await controller.addTask(onDate);
      await controller.addTask(offDate);

      final ids = controller.tasksForDate(d).map((t) => t.id).toList();
      expect(ids, [onDate.id]);
    });

    test('allTasks / allCompletedTasks span every scope', () async {
      final inbox = Task(title: 'inbox');
      final listed = Task(title: 'listed', listId: 'L');
      await controller.addTask(inbox);
      await controller.addTask(listed);
      await controller.toggleCompleted(listed.id);

      expect(controller.allTasks.map((t) => t.id).toSet(), {inbox.id, listed.id});
      expect(controller.allCompletedTasks.map((t) => t.id), [listed.id]);
    });
  });

  // ── Completed ordering ────────────────────────────────────────────────────

  group('completed ordering', () {
    test('incomplete first, most-recently-completed first among completed',
        () async {
      final a = Task(title: 'a', listId: 'L');
      final b = Task(title: 'b', listId: 'L');
      final c = Task(title: 'c', listId: 'L');
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.addTask(c);

      // Complete a, then b (b is more recent).
      expect(await controller.toggleCompleted(a.id), TaskToggleResult.completed);
      expect(await controller.toggleCompleted(b.id), TaskToggleResult.completed);

      final ordered = controller.tasksForList('L').map((t) => t.id).toList();
      // Incomplete c first; then completed b (most recent) then a.
      expect(ordered.first, c.id);
      expect(ordered.sublist(1), [b.id, a.id]);
    });

    test('toggleCompleted returns uncompleted when un-checking', () async {
      final t = Task(title: 'x');
      await controller.addTask(t);
      await controller.toggleCompleted(t.id);
      expect(
          await controller.toggleCompleted(t.id), TaskToggleResult.uncompleted);
      expect(controller.taskById(t.id)!.isCompleted, isFalse);
    });

    test('toggleCompleted on unknown id returns none', () async {
      expect(await controller.toggleCompleted('missing'), TaskToggleResult.none);
    });
  });

  // ── Recurrence ────────────────────────────────────────────────────────────

  group('recurrence', () {
    test('completing a daily recurring task advances dueDate, stays incomplete',
        () async {
      final t = Task(
        title: 'daily',
        dueDate: today(),
        recurrence:
            const Recurrence(type: RecurrenceType.daily, interval: 1).toJson(),
      );
      await controller.addTask(t);

      final result = await controller.toggleCompleted(t.id);
      expect(result, TaskToggleResult.recurrenceAdvanced);

      final updated = controller.taskById(t.id)!;
      expect(updated.isCompleted, isFalse);
      expect(dateOnly(updated.dueDate!),
          today().add(const Duration(days: 1)));
    });
  });

  // ── Subtasks ──────────────────────────────────────────────────────────────

  group('subtasks', () {
    test('subtasksOf returns children oldest-first; excluded from smart lists',
        () async {
      final parent = Task(title: 'parent');
      await controller.addTask(parent);

      final sub1 = Task(
          title: 'sub1',
          parentTaskId: parent.id,
          creationDate: DateTime(2020, 1, 1));
      final sub2 = Task(
          title: 'sub2',
          parentTaskId: parent.id,
          creationDate: DateTime(2020, 1, 2));
      // Add newest first to confirm sorting is by creationDate not insert order.
      await controller.addTask(sub2);
      await controller.addTask(sub1);

      final subs = controller.subtasksOf(parent.id).map((t) => t.id).toList();
      expect(subs, [sub1.id, sub2.id]);

      // Subtasks excluded from inbox / allTasks.
      expect(controller.inboxTasks.map((t) => t.id), isNot(contains(sub1.id)));
      expect(controller.allTasks.map((t) => t.id), isNot(contains(sub2.id)));
      expect(controller.inboxTasks.map((t) => t.id), contains(parent.id));
    });

    test('subtaskCount / subtaskCompletedCount', () async {
      final parent = Task(title: 'parent');
      await controller.addTask(parent);
      final s1 = Task(title: 's1', parentTaskId: parent.id);
      final s2 = Task(title: 's2', parentTaskId: parent.id);
      await controller.addTask(s1);
      await controller.addTask(s2);
      await controller.toggleCompleted(s1.id);

      expect(controller.subtaskCount(parent.id), 2);
      expect(controller.subtaskCompletedCount(parent.id), 1);
    });
  });

  // ── Tags ──────────────────────────────────────────────────────────────────

  group('tags', () {
    test('addOrGetTag dedups case-insensitively', () async {
      final first = await controller.addOrGetTag('Work');
      final second = await controller.addOrGetTag('work');

      expect(second.id, first.id);
      expect(controller.tags.length, 1);
    });

    test('tagsForTask / tasksWithTag', () async {
      final tag = await controller.addOrGetTag('home');
      final tagged = Task(title: 'tagged', tagIds: [tag.id]);
      final plain = Task(title: 'plain');
      await controller.addTask(tagged);
      await controller.addTask(plain);

      expect(controller.tagsForTask(tagged).map((t) => t.id), [tag.id]);
      expect(controller.tasksWithTag(tag.id).map((t) => t.id), [tagged.id]);
    });

    test('deleteTag removes tag and strips it from referencing tasks',
        () async {
      final tag = await controller.addOrGetTag('temp');
      final task = Task(title: 'tagged', tagIds: [tag.id]);
      await controller.addTask(task);

      await controller.deleteTag(tag.id);
      expect(controller.tagById(tag.id), isNull);
      expect(controller.taskById(task.id)!.tagIds, isNot(contains(tag.id)));

      // Persisted: reload and confirm tagId is gone.
      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.taskById(task.id)!.tagIds, isNot(contains(tag.id)));
      expect(fresh.tags, isEmpty);
    });
  });

  // ── Soft delete ─────────────────────────────────────────────────────────

  group('soft delete', () {
    test('deleteTask soft-deletes task + subtree with shared deletedDate',
        () async {
      final parent = Task(title: 'parent');
      await controller.addTask(parent);
      final sub = Task(title: 'sub', parentTaskId: parent.id);
      await controller.addTask(sub);

      await controller.deleteTask(parent.id);

      expect(controller.inboxTasks.map((t) => t.id), isNot(contains(parent.id)));
      final trashedIds = controller.trashedTasks.map((t) => t.id).toSet();
      expect(trashedIds, containsAll({parent.id, sub.id}));

      // Shared deletedDate.
      final pd = controller.trashedTasks.firstWhere((t) => t.id == parent.id);
      final sd = controller.trashedTasks.firstWhere((t) => t.id == sub.id);
      expect(pd.deletedDate!.millisecondsSinceEpoch,
          sd.deletedDate!.millisecondsSinceEpoch);
    });

    test('restoreAt restores everything sharing a deletedDate', () async {
      final parent = Task(title: 'parent');
      await controller.addTask(parent);
      final sub = Task(title: 'sub', parentTaskId: parent.id);
      await controller.addTask(sub);
      await controller.deleteTask(parent.id);

      final dd = controller.trashedTasks
          .firstWhere((t) => t.id == parent.id)
          .deletedDate!;
      await controller.restoreAt(dd);

      expect(controller.trashedTasks, isEmpty);
      expect(controller.taskById(parent.id), isNotNull);
      expect(controller.subtasksOf(parent.id).map((t) => t.id), [sub.id]);
    });

    test('restoreTask restores to a target list', () async {
      final t = Task(title: 'moved', listId: 'A');
      await controller.addTask(t);
      await controller.deleteTask(t.id);

      await controller.restoreTask(t.id, 'B');
      expect(controller.trashedTasks, isEmpty);
      expect(controller.taskById(t.id)!.listId, 'B');
      expect(controller.tasksForList('B').map((x) => x.id), contains(t.id));
    });

    test('permanentlyDeleteTask removes a single trashed task', () async {
      final a = Task(title: 'a');
      final b = Task(title: 'b');
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.deleteTask(a.id);
      await controller.deleteTask(b.id);

      await controller.permanentlyDeleteTask(a.id);
      expect(controller.trashedTasks.map((t) => t.id), [b.id]);

      // Hard-deleted: not recoverable on reload.
      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.trashedTasks.map((t) => t.id), [b.id]);
    });

    test('permanentlyDeleteAllTrashed empties trash', () async {
      final a = Task(title: 'a');
      final b = Task(title: 'b');
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.deleteTask(a.id);
      await controller.deleteTask(b.id);

      await controller.permanentlyDeleteAllTrashed();
      expect(controller.trashedTasks, isEmpty);

      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.trashedTasks, isEmpty);
    });
  });

  // ── Reorder ───────────────────────────────────────────────────────────────

  group('reorder', () {
    test('reorderTasks updates inbox order and persists sortOrder', () async {
      final a = Task(title: 'a');
      final b = Task(title: 'b');
      final c = Task(title: 'c');
      // Added newest-first; default sort = sortOrder(0) tie → newest first,
      // so initial display order is [c, b, a].
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.addTask(c);
      expect(controller.inboxTasks.map((t) => t.id), [c.id, b.id, a.id]);

      // Move the first item (c) to the last position.
      await controller.reorderTasks(listId: null, oldIndex: 0, newIndex: 3);
      expect(controller.inboxTasks.map((t) => t.id), [b.id, a.id, c.id]);

      // sortOrder persisted.
      final fresh = await loadedController(db);
      addTearDown(fresh.dispose);
      expect(fresh.inboxTasks.map((t) => t.id), [b.id, a.id, c.id]);
    });

    test('reorderTaskBefore moves a task ahead of another', () async {
      final a = Task(title: 'a', listId: 'L');
      final b = Task(title: 'b', listId: 'L');
      final c = Task(title: 'c', listId: 'L');
      await controller.addTask(a);
      await controller.addTask(b);
      await controller.addTask(c);
      // Initial display order [c, b, a].
      expect(controller.tasksForList('L').map((t) => t.id), [c.id, b.id, a.id]);

      // Move a to before c (i.e. first).
      await controller.reorderTaskBefore(
        movedTaskId: a.id,
        beforeTaskId: c.id,
        listId: 'L',
        sectionId: null,
      );
      expect(controller.tasksForList('L').map((t) => t.id), [a.id, c.id, b.id]);

      // beforeTaskId == null lands at the end.
      await controller.reorderTaskBefore(
        movedTaskId: a.id,
        beforeTaskId: null,
        listId: 'L',
        sectionId: null,
      );
      expect(controller.tasksForList('L').map((t) => t.id), [c.id, b.id, a.id]);
    });
  });

  // ── Counts ────────────────────────────────────────────────────────────────

  group('counts', () {
    test('inbox / today / tomorrow / upcoming uncompleted counts', () async {
      await controller.addTask(Task(title: 'inbox1'));
      await controller.addTask(Task(title: 'inbox2'));
      await controller.addTask(Task(title: 'today', dueDate: today()));
      await controller.addTask(
          Task(title: 'tomorrow', dueDate: today().add(const Duration(days: 1))));
      await controller.addTask(
          Task(title: 'upcoming', dueDate: today().add(const Duration(days: 3))));

      // inbox = tasks with listId null (incl. the dated ones, which have no list)
      expect(controller.inboxUncompletedCount, 5);
      expect(controller.todayUncompletedCount, 1);
      expect(controller.tomorrowUncompletedCount, 1);
      expect(controller.upcomingUncompletedCount, 2); // tomorrow + upcoming
    });

    test('completing a task drops the relevant counts', () async {
      final t = Task(title: 'today', dueDate: today());
      await controller.addTask(t);
      expect(controller.todayUncompletedCount, 1);
      await controller.toggleCompleted(t.id);
      expect(controller.todayUncompletedCount, 0);
      expect(controller.completedTasksCount, 1);
    });

    test('uncompletedCountForList', () async {
      await controller.addTask(Task(title: 'a', listId: 'L'));
      final done = Task(title: 'b', listId: 'L');
      await controller.addTask(done);
      await controller.toggleCompleted(done.id);

      expect(controller.uncompletedCountForList('L'), 1);
      expect(controller.uncompletedCountForLists(['L']), 1);
    });
  });
}
