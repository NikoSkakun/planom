import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/goal.dart';
import '../models/goal_milestone.dart';

/// Owns goals and their milestones.
///
/// Progress is derived, never stored on the goal beyond the raw inputs:
/// - numeric goals → [Goal.currentAmount] / [Goal.targetAmount];
/// - milestone goals with milestones → done / total milestones;
/// - milestone goals without milestones → 0 or 1 from [Goal.isCompleted].
class GoalController with ChangeNotifier {
  GoalController(this._db);

  final DatabaseService _db;

  List<Goal> _goals = [];
  List<GoalMilestone> _milestones = [];

  List<Goal> get goals => List.unmodifiable(_goals);
  List<Goal> get activeGoals =>
      _goals.where((g) => !g.isArchived && !g.isCompleted).toList();
  List<Goal> get completedGoals =>
      _goals.where((g) => g.isCompleted && !g.isArchived).toList();
  List<Goal> get archivedGoals => _goals.where((g) => g.isArchived).toList();
  List<GoalMilestone> get milestones => List.unmodifiable(_milestones);

  bool get isEmpty => _goals.isEmpty;

  Future<void> load() async {
    _goals = await _db.getGoals();
    _milestones = await _db.getGoalMilestones();
    notifyListeners();
  }

  Goal? goalById(String id) {
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<GoalMilestone> milestonesFor(String goalId) =>
      _milestones.where((m) => m.goalId == goalId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  int milestonesDone(String goalId) =>
      _milestones.where((m) => m.goalId == goalId && m.isCompleted).length;

  int milestonesTotal(String goalId) =>
      _milestones.where((m) => m.goalId == goalId).length;

  /// Fractional progress in [0, 1].
  double progress(Goal goal) {
    if (goal.isNumeric) {
      final target = goal.targetAmount ?? 0;
      if (target <= 0) return goal.isCompleted ? 1 : 0;
      return (goal.currentAmount / target).clamp(0.0, 1.0);
    }
    final total = milestonesTotal(goal.id);
    if (total == 0) return goal.isCompleted ? 1 : 0;
    return (milestonesDone(goal.id) / total).clamp(0.0, 1.0);
  }

  /// Whether [goal]'s underlying progress has reached its target (independent of
  /// the manual [Goal.isCompleted] flag).
  bool reachedTarget(Goal goal) {
    if (goal.isNumeric) {
      final target = goal.targetAmount ?? 0;
      return target > 0 && goal.currentAmount >= target;
    }
    final total = milestonesTotal(goal.id);
    return total > 0 && milestonesDone(goal.id) >= total;
  }

  // ── Goal CRUD ──────────────────────────────────────────────────────────────

  Future<void> addGoal(Goal goal) async {
    final maxOrder =
        _goals.fold<int>(-1, (m, g) => g.sortOrder > m ? g.sortOrder : m);
    final ordered = goal.copyWith(sortOrder: maxOrder + 1);
    await _db.insertGoal(ordered);
    _goals.add(ordered);
    notifyListeners();
  }

  Future<void> updateGoal(Goal goal) async {
    await _db.updateGoal(goal);
    final i = _goals.indexWhere((g) => g.id == goal.id);
    if (i != -1) _goals[i] = goal;
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
    _goals.removeWhere((g) => g.id == id);
    _milestones.removeWhere((m) => m.goalId == id);
    notifyListeners();
  }

  /// Re-inserts a deleted goal and its milestones (used by the Undo banner).
  Future<void> restoreGoal(Goal goal, List<GoalMilestone> milestones) async {
    await _db.insertGoal(goal);
    _goals.add(goal);
    for (final m in milestones) {
      await _db.insertGoalMilestone(m);
      _milestones.add(m);
    }
    notifyListeners();
  }

  /// Marks a goal complete / incomplete, stamping the completion date.
  Future<void> setCompleted(Goal goal, bool completed) async {
    final updated = completed
        ? goal.copyWith(isCompleted: true, completionDate: DateTime.now())
        : goal.copyWith(isCompleted: false, clearCompletionDate: true);
    await updateGoal(updated);
  }

  Future<void> setArchived(Goal goal, bool archived) =>
      updateGoal(goal.copyWith(isArchived: archived));

  /// Adds [delta] (may be negative) to a numeric goal's current amount, clamped
  /// to ≥ 0, and auto-completes the goal when the target is reached.
  Future<void> addProgress(Goal goal, int delta) async {
    if (!goal.isNumeric) return;
    final next = (goal.currentAmount + delta).clamp(0, 1 << 31);
    var updated = goal.copyWith(currentAmount: next);
    final target = goal.targetAmount ?? 0;
    if (target > 0 && next >= target && !goal.isCompleted) {
      updated = updated.copyWith(
          isCompleted: true, completionDate: DateTime.now());
    } else if (goal.isCompleted && (target <= 0 || next < target)) {
      updated = updated.copyWith(isCompleted: false, clearCompletionDate: true);
    }
    await updateGoal(updated);
  }

  /// Sets a numeric goal's absolute progress.
  Future<void> setProgress(Goal goal, int amount) =>
      addProgress(goal, amount - goal.currentAmount);

  Future<void> reorderGoals(List<Goal> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final idx = _goals.indexWhere((g) => g.id == ordered[i].id);
      if (idx != -1) _goals[idx] = _goals[idx].copyWith(sortOrder: i);
    }
    notifyListeners();
    await _db.updateGoalSortOrders(_goals);
  }

  // ── Milestone CRUD ───────────────────────────────────────────────────────

  Future<void> addMilestone(String goalId, String title) async {
    final existing = milestonesFor(goalId);
    final order = existing.isEmpty ? 0 : existing.last.sortOrder + 1;
    final milestone =
        GoalMilestone(goalId: goalId, title: title, sortOrder: order);
    await _db.insertGoalMilestone(milestone);
    _milestones.add(milestone);
    await _syncGoalCompletionFromMilestones(goalId);
    notifyListeners();
  }

  Future<void> updateMilestone(GoalMilestone milestone) async {
    await _db.updateGoalMilestone(milestone);
    final i = _milestones.indexWhere((m) => m.id == milestone.id);
    if (i != -1) _milestones[i] = milestone;
    notifyListeners();
  }

  Future<void> toggleMilestone(GoalMilestone milestone) async {
    final updated = milestone.copyWith(
      isCompleted: !milestone.isCompleted,
      completionDate: !milestone.isCompleted ? DateTime.now() : null,
      clearCompletionDate: milestone.isCompleted,
    );
    await _db.updateGoalMilestone(updated);
    final i = _milestones.indexWhere((m) => m.id == milestone.id);
    if (i != -1) _milestones[i] = updated;
    await _syncGoalCompletionFromMilestones(milestone.goalId);
    notifyListeners();
  }

  Future<void> deleteMilestone(String id) async {
    final m = _milestones.firstWhere((m) => m.id == id,
        orElse: () => GoalMilestone(goalId: '', title: ''));
    await _db.deleteGoalMilestone(id);
    _milestones.removeWhere((m) => m.id == id);
    if (m.goalId.isNotEmpty) {
      await _syncGoalCompletionFromMilestones(m.goalId);
    }
    notifyListeners();
  }

  Future<void> reorderMilestones(
      String goalId, List<GoalMilestone> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final idx = _milestones.indexWhere((m) => m.id == ordered[i].id);
      if (idx != -1) _milestones[idx] = _milestones[idx].copyWith(sortOrder: i);
    }
    notifyListeners();
    await _db.updateGoalMilestoneSortOrders(
        _milestones.where((m) => m.goalId == goalId).toList());
  }

  /// Keeps a milestone goal's completion flag in step with its milestones: all
  /// done → completed; any undone → not completed. Goals with no milestones are
  /// left under manual control.
  Future<void> _syncGoalCompletionFromMilestones(String goalId) async {
    final goal = goalById(goalId);
    if (goal == null || goal.isNumeric) return;
    final total = milestonesTotal(goalId);
    if (total == 0) return;
    final allDone = milestonesDone(goalId) == total;
    if (allDone == goal.isCompleted) return;
    final updated = allDone
        ? goal.copyWith(isCompleted: true, completionDate: DateTime.now())
        : goal.copyWith(isCompleted: false, clearCompletionDate: true);
    await _db.updateGoal(updated);
    final i = _goals.indexWhere((g) => g.id == goalId);
    if (i != -1) _goals[i] = updated;
  }
}
