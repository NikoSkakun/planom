import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../tasks/task_controller.dart';

/// Short title for a source row: what kind of thing it tracks.
String goalSourceTitle(S s, GoalSource source) {
  if (source.kind == GoalSourceKind.manual) return s.goalSourcePicked;
  switch (source.scopeType) {
    case GoalScopeType.all:
      return s.goalScopeAll;
    case GoalScopeType.folders:
      return s.goalScopeFolders;
    case GoalScopeType.lists:
      return s.goalScopeLists;
    case GoalScopeType.sections:
      return s.goalScopeSections;
  }
}

String goalDateFilterLabel(S s, GoalDateFilter filter) {
  switch (filter) {
    case GoalDateFilter.any:
      return s.goalDateAny;
    case GoalDateFilter.noDate:
      return s.goalDateNone;
    case GoalDateFilter.overdue:
      return s.goalDateOverdue;
    case GoalDateFilter.today:
      return s.today;
    case GoalDateFilter.tomorrow:
      return s.tomorrow;
    case GoalDateFilter.thisWeek:
      return s.goalDateThisWeek;
    case GoalDateFilter.thisMonth:
      return s.goalDateThisMonth;
    case GoalDateFilter.range:
      return s.goalDateRange;
  }
}

String goalPriorityLabel(S s, int priority) {
  switch (priority) {
    case 1:
      return s.priorityLow;
    case 2:
      return s.priorityMed;
    case 3:
      return s.priorityHigh;
    default:
      return s.priorityNone;
  }
}

/// One-line human summary of what a source resolves to — the scope's named
/// containers plus any narrowing filters, e.g.
/// `Work, Personal · #launch · High · This week`.
String goalSourceDetail(
  BuildContext context,
  GoalSource source, {
  required FolderController folderController,
  required TaskController taskController,
}) {
  final s = S.of(context);
  final parts = <String>[];

  if (source.kind == GoalSourceKind.manual) {
    parts.add(s.goalTasksSelected(source.taskIds.length));
    return parts.join(' · ');
  }

  switch (source.scopeType) {
    case GoalScopeType.all:
      parts.add(s.goalScopeAll);
    case GoalScopeType.folders:
      parts.add(_names(
        source.scopeIds,
        (id) => folderController.folderById(id)?.name,
        s,
      ));
    case GoalScopeType.lists:
      parts.add(_names(
        source.scopeIds,
        (id) => folderController.listById(id)?.name,
        s,
      ));
    case GoalScopeType.sections:
      parts.add(_names(
        source.scopeIds,
        (id) => folderController.sectionById(id)?.name,
        s,
      ));
  }

  if (source.tagIds.isNotEmpty) {
    parts.add(source.tagIds
        .map((id) => taskController.tagById(id)?.name)
        .whereType<String>()
        .map((name) => '#$name')
        .join(', '));
  }
  if (source.priorities.isNotEmpty) {
    final sorted = [...source.priorities]..sort((a, b) => b.compareTo(a));
    parts.add(sorted.map((p) => goalPriorityLabel(s, p)).join(', '));
  }
  if (source.dateFilter != GoalDateFilter.any) {
    parts.add(goalDateFilterLabel(s, source.dateFilter));
  }
  return parts.where((p) => p.isNotEmpty).join(' · ');
}

/// Joins up to three resolved names, then "+N". Ids that no longer resolve
/// (container deleted since) are skipped so a stale rule still reads sanely.
String _names(List<String> ids, String? Function(String) lookup, S s) {
  final names = ids.map(lookup).whereType<String>().toList();
  if (names.isEmpty) return s.goalScopeNothingSelected;
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} +${names.length - 3}';
}
