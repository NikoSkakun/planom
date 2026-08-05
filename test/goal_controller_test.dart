import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/goals/goal_controller.dart';
import 'package:planom/src/models/app_folder.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/models/goal.dart';
import 'package:planom/src/models/list_section.dart';
import 'package:planom/src/models/tag.dart';
import 'package:planom/src/models/task.dart';
import 'package:planom/src/tasks/task_controller.dart';
import 'package:planom/src/utils/day_boundary.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late TaskController tasks;
  late FolderController folders;
  late GoalController goals;

  setUp(() async {
    db = freshDb();
    tasks = TaskController(db);
    folders = FolderController(db);
    goals = GoalController(db, taskController: tasks, folderController: folders);
    await tasks.load();
    await folders.load();
    await goals.load();
  });

  Future<Task> addTask(
    String title, {
    String? listId,
    String? sectionId,
    bool completed = false,
    int priority = 0,
    DateTime? due,
    List<String> tagIds = const [],
    String? parentTaskId,
  }) async {
    final task = Task(
      title: title,
      listId: listId,
      sectionId: sectionId,
      isCompleted: completed,
      priority: priority,
      dueDate: due,
      tagIds: tagIds,
      parentTaskId: parentTaskId,
    );
    await tasks.addTask(task);
    return task;
  }

  Future<Goal> addGoal(List<GoalSource> sources, {String name = 'Ship it'}) async {
    final goal = Goal(name: name, sources: sources);
    await goals.addGoal(goal);
    return goal;
  }

  group('CRUD', () {
    test('add / update / delete round-trip through the database', () async {
      final goal = await addGoal([GoalSource()], name: 'Launch');
      expect(goals.goals.length, 1);

      await goals.updateGoal(goal.copyWith(name: 'Launch v2'));
      expect(goals.goalById(goal.id)?.name, 'Launch v2');

      final reloaded = GoalController(db,
          taskController: tasks, folderController: folders);
      await reloaded.load();
      expect(reloaded.goalById(goal.id)?.name, 'Launch v2');

      await goals.deleteGoal(goal.id);
      expect(goals.goals, isEmpty);
      final afterDelete = GoalController(db,
          taskController: tasks, folderController: folders);
      await afterDelete.load();
      expect(afterDelete.goals, isEmpty);
    });

    test('sources survive the JSON round-trip', () async {
      final source = GoalSource(
        scopeType: GoalScopeType.folders,
        scopeIds: const ['f1', 'f2'],
        tagIds: const ['t1'],
        priorities: const [3, 2],
        dateFilter: GoalDateFilter.thisWeek,
      );
      final goal = await addGoal([source]);

      final reloaded = GoalController(db,
          taskController: tasks, folderController: folders);
      await reloaded.load();
      final restored = reloaded.goalById(goal.id)!.sources.single;
      expect(restored.id, source.id);
      expect(restored.scopeType, GoalScopeType.folders);
      expect(restored.scopeIds, ['f1', 'f2']);
      expect(restored.tagIds, ['t1']);
      expect(restored.priorities, [3, 2]);
      expect(restored.dateFilter, GoalDateFilter.thisWeek);
    });

    test('a corrupt sources blob degrades to an empty goal, not a crash',
        () async {
      final goal = Goal(name: 'Broken');
      final map = goal.toMap()..['sources'] = '{not json';
      expect(Goal.fromMap(map).sources, isEmpty);
    });

    test('reorderGoals renumbers and persists', () async {
      final a = await addGoal([GoalSource()], name: 'A');
      await addGoal([GoalSource()], name: 'B');
      await addGoal([GoalSource()], name: 'C');

      await goals.reorderGoals(0, 3); // A to the end

      final reloaded = GoalController(db,
          taskController: tasks, folderController: folders);
      await reloaded.load();
      expect(reloaded.goals.map((g) => g.name), ['B', 'C', 'A']);
      expect(reloaded.goals.last.id, a.id);
    });
  });

  group('manual sources', () {
    test('track exactly the picked tasks', () async {
      final picked = await addTask('Picked');
      await addTask('Ignored');
      final goal = await addGoal([
        GoalSource(kind: GoalSourceKind.manual, taskIds: [picked.id]),
      ]);

      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Picked']);
    });

    test('a deleted task drops out instead of breaking the goal', () async {
      final picked = await addTask('Picked');
      final goal = await addGoal([
        GoalSource(kind: GoalSourceKind.manual, taskIds: [picked.id, 'gone']),
      ]);
      await tasks.deleteTask(picked.id);

      expect(goals.tasksForGoal(goal), isEmpty);
      expect(goals.progressFor(goal).total, 0);
    });
  });

  group('rule sources', () {
    test('a folder scope picks up tasks added later', () async {
      await folders.addFolder(AppFolder(id: 'f1', name: 'Work'));
      await folders.addList(AppList(id: 'l1', name: 'Sprint', folderId: 'f1'));
      await folders.addList(AppList(id: 'l2', name: 'Personal'));
      await addTask('Old', listId: 'l1');
      await addTask('Elsewhere', listId: 'l2');

      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.folders, scopeIds: const ['f1']),
      ]);
      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Old']);

      // The whole point of a rule: a task created afterwards joins the goal.
      await addTask('New', listId: 'l1');
      expect(
        goals.tasksForGoal(goal).map((t) => t.title).toSet(),
        {'Old', 'New'},
      );
    });

    test('a folder scope reaches lists in nested subfolders', () async {
      await folders.addFolder(AppFolder(id: 'f1', name: 'Work'));
      await folders
          .addFolder(AppFolder(id: 'f2', name: 'Q1', parentFolderId: 'f1'));
      await folders.addList(AppList(id: 'l1', name: 'Deep', folderId: 'f2'));
      await addTask('Nested', listId: 'l1');

      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.folders, scopeIds: const ['f1']),
      ]);
      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Nested']);
    });

    test('list and section scopes', () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      await folders.addSection(
          ListSection(id: 's1', listId: 'l1', name: 'Now'));
      await addTask('In section', listId: 'l1', sectionId: 's1');
      await addTask('Top of list', listId: 'l1');
      await addTask('Inbox task');

      final listGoal = await addGoal([
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
      ], name: 'By list');
      expect(goals.tasksForGoal(listGoal).length, 2);

      final sectionGoal = await addGoal([
        GoalSource(scopeType: GoalScopeType.sections, scopeIds: const ['s1']),
      ], name: 'By section');
      expect(goals.tasksForGoal(sectionGoal).map((t) => t.title),
          ['In section']);
    });

    test('tag / priority / date filters narrow the scope', () async {
      final tag = await tasks.addOrGetTag('launch');
      final other = Tag(name: 'misc');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);

      await addTask('Tagged high today',
          tagIds: [tag.id], priority: 3, due: day);
      await addTask('Tagged low today', tagIds: [tag.id], priority: 1, due: day);
      await addTask('Untagged high today', priority: 3, due: day);
      await addTask('Tagged high no date', tagIds: [tag.id], priority: 3);
      expect(other.name, 'misc'); // guard: unused-tag construction stays valid

      final byTag = await addGoal([
        GoalSource(tagIds: [tag.id]),
      ], name: 'tag');
      expect(goals.tasksForGoal(byTag).length, 3);

      final byTagAndPriority = await addGoal([
        GoalSource(tagIds: [tag.id], priorities: const [3]),
      ], name: 'tag+prio');
      expect(goals.tasksForGoal(byTagAndPriority).length, 2);

      final byTagPriorityDate = await addGoal([
        GoalSource(
          tagIds: [tag.id],
          priorities: const [3],
          dateFilter: GoalDateFilter.today,
        ),
      ], name: 'tag+prio+date');
      expect(goals.tasksForGoal(byTagPriorityDate).map((t) => t.title),
          ['Tagged high today']);
    });

    test('the no-date filter matches only undated tasks', () async {
      await addTask('Undated');
      await addTask('Dated', due: DateTime.now());
      final goal = await addGoal([
        GoalSource(dateFilter: GoalDateFilter.noDate),
      ]);
      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Undated']);
    });

    test('a date range is inclusive at both ends', () async {
      final base = DateTime(2026, 5, 10);
      await addTask('Before', due: DateTime(2026, 5, 9));
      await addTask('From', due: base);
      await addTask('Middle', due: DateTime(2026, 5, 12));
      await addTask('To', due: DateTime(2026, 5, 14));
      await addTask('After', due: DateTime(2026, 5, 15));

      final goal = await addGoal([
        GoalSource(
          dateFilter: GoalDateFilter.range,
          from: base,
          to: DateTime(2026, 5, 14),
        ),
      ]);
      expect(
        goals.tasksForGoal(goal).map((t) => t.title).toSet(),
        {'From', 'Middle', 'To'},
      );
    });

    test('subtasks never join a goal', () async {
      final parent = await addTask('Parent');
      await addTask('Child', parentTaskId: parent.id);
      final goal = await addGoal([GoalSource()]);
      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Parent']);
    });
  });

  group('union + progress', () {
    test('sources are unioned and de-duplicated', () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      final shared = await addTask('Shared', listId: 'l1');
      await addTask('List only', listId: 'l1');

      final goal = await addGoal([
        GoalSource(kind: GoalSourceKind.manual, taskIds: [shared.id]),
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
      ]);
      expect(goals.tasksForGoal(goal).length, 2);
    });

    test('progress counts completed over total, empty reads as 0', () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      await addTask('Done', listId: 'l1', completed: true);
      await addTask('Open', listId: 'l1');
      await addTask('Also open', listId: 'l1');

      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
      ]);
      final progress = goals.progressFor(goal);
      expect(progress.total, 3);
      expect(progress.completed, 1);
      expect(progress.remaining, 2);
      expect(progress.percent, 33);
      expect(progress.isComplete, isFalse);

      final empty = await addGoal([
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['nope']),
      ], name: 'empty');
      expect(goals.progressFor(empty).fraction, 0.0);
      expect(goals.progressFor(empty).isEmpty, isTrue);
    });

    test('completing a task moves the goal forward', () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      final task = await addTask('Open', listId: 'l1');
      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
      ]);
      expect(goals.progressFor(goal).completed, 0);

      await tasks.toggleCompleted(task.id);
      expect(goals.progressFor(goal).completed, 1);
      expect(goals.progressFor(goal).isComplete, isTrue);
    });

    test('tracked tasks list uncompleted first', () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      await addTask('Done', listId: 'l1', completed: true);
      await addTask('Open', listId: 'l1');

      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
      ]);
      expect(goals.tasksForGoal(goal).first.title, 'Open');
      expect(goals.tasksForGoal(goal).last.title, 'Done');
    });
  });

  group('regressions', () {
    tearDown(() => DayBoundary.firstWeekday = DateTime.monday);

    test('the week filter honours the first-day-of-week setting', () async {
      // Sunday 2026-05-10 … Saturday 2026-05-16 when weeks start on Sunday;
      // Monday 2026-05-11 … Sunday 2026-05-17 when they start on Monday.
      final sunday = DateTime(2026, 5, 10);
      final start = DayBoundary.startOfWeek(DateTime(2026, 5, 13));
      expect(start, DateTime(2026, 5, 11), reason: 'Monday default');

      DayBoundary.firstWeekday = DateTime.sunday;
      expect(DayBoundary.startOfWeek(DateTime(2026, 5, 13)), sunday);
    });

    test('a task in a deleted section drops out of a section-scoped goal',
        () async {
      await folders.addList(AppList(id: 'l1', name: 'Sprint'));
      await folders.addSection(
          ListSection(id: 's1', listId: 'l1', name: 'Now'));
      await addTask('In section', listId: 'l1', sectionId: 's1');

      final goal = await addGoal([
        GoalSource(scopeType: GoalScopeType.sections, scopeIds: const ['s1']),
      ]);
      expect(goals.tasksForGoal(goal).length, 1);

      await folders.deleteSection('s1');
      expect(goals.tasksForGoal(goal), isEmpty,
          reason: 'tasks left pointing at a ghost section must not count');
    });

    test('restoring a deleted goal keeps its position', () async {
      final first = await addGoal([GoalSource()], name: 'First');
      await addGoal([GoalSource()], name: 'Second');
      await addGoal([GoalSource()], name: 'Third');

      await goals.deleteGoal(first.id);
      await goals.restoreGoal(first);

      expect(goals.goals.map((g) => g.name), ['First', 'Second', 'Third']);
    });

    test('the date filters use calendar arithmetic (DST-safe)', () async {
      // A duration-based "+1 day" lands on the same date across a
      // spring-forward boundary; calendar arithmetic doesn't.
      await addTask('Tomorrow', due: DayBoundary.tomorrow());
      final goal = await addGoal([
        GoalSource(dateFilter: GoalDateFilter.tomorrow),
      ]);
      expect(goals.tasksForGoal(goal).map((t) => t.title), ['Tomorrow']);
    });
  });
}
