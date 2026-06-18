import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/goals/goal_controller.dart';
import 'package:planom/src/models/goal.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  test('numeric goal progress and auto-completion', () async {
    final db = freshDb();
    final c = GoalController(db);
    await c.load();
    final goal = Goal(title: 'Read 10 books', type: Goal.typeNumeric, targetAmount: 10);
    await c.addGoal(goal);

    await c.addProgress(c.goalById(goal.id)!, 4);
    expect(c.goalById(goal.id)!.currentAmount, 4);
    expect(c.progress(c.goalById(goal.id)!), closeTo(0.4, 1e-9));
    expect(c.goalById(goal.id)!.isCompleted, isFalse);

    await c.addProgress(c.goalById(goal.id)!, 6);
    expect(c.goalById(goal.id)!.isCompleted, isTrue);

    // Dropping below target re-opens the goal.
    await c.addProgress(c.goalById(goal.id)!, -1);
    expect(c.goalById(goal.id)!.isCompleted, isFalse);
  });

  test('milestone goal completes when all milestones are done', () async {
    final db = freshDb();
    final c = GoalController(db);
    await c.load();
    final goal = Goal(title: 'Launch app', type: Goal.typeMilestone);
    await c.addGoal(goal);

    await c.addMilestone(goal.id, 'Design');
    await c.addMilestone(goal.id, 'Build');
    expect(c.milestonesTotal(goal.id), 2);
    expect(c.goalById(goal.id)!.isCompleted, isFalse);

    for (final m in c.milestonesFor(goal.id)) {
      await c.toggleMilestone(m);
    }
    expect(c.milestonesDone(goal.id), 2);
    expect(c.goalById(goal.id)!.isCompleted, isTrue);
    expect(c.progress(c.goalById(goal.id)!), 1.0);
  });

  test('delete and restore round-trips milestones', () async {
    final db = freshDb();
    final c = GoalController(db);
    await c.load();
    final goal = Goal(title: 'Trip', type: Goal.typeMilestone);
    await c.addGoal(goal);
    await c.addMilestone(goal.id, 'Book flights');
    final milestones = c.milestonesFor(goal.id);

    await c.deleteGoal(goal.id);
    expect(c.goals, isEmpty);
    expect(c.milestones, isEmpty);

    await c.restoreGoal(goal, milestones);
    expect(c.goalById(goal.id), isNotNull);
    expect(c.milestonesFor(goal.id).length, 1);
  });

  test('persists across reloads', () async {
    final db = freshDb();
    final c = GoalController(db);
    await c.load();
    final goal = Goal(title: 'Save', type: Goal.typeNumeric, targetAmount: 100);
    await c.addGoal(goal);
    await c.addProgress(c.goalById(goal.id)!, 25);

    final c2 = GoalController(db);
    await c2.load();
    expect(c2.goalById(goal.id)?.currentAmount, 25);
  });
}
