import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/task.dart';
import '../utils/fast_route.dart';
import '../utils/undo_controller.dart';
import 'birthday_row.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

/// Body widget rendered inside ListTaskView when the list's type is
/// Birthdays. Sorts contacts by their next celebration date and splits
/// "this year" from "next year" with a year-label separator row.
class BirthdayListView extends StatelessWidget {
  const BirthdayListView({
    super.key,
    required this.listId,
    required this.taskController,
    required this.folderController,
  });

  final String listId;
  final TaskController taskController;
  final FolderController folderController;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: taskController,
      builder: (context, _) {
        final all = taskController
            .tasksForList(listId)
            .where((t) => t.isBirthday)
            .toList();

        if (all.isEmpty) {
          return Center(
            child: Text(
              s.noTasks,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Build (task, celebrationDate) tuples spanning this and next year.
        // For each task we compute the next occurrence on/after today, plus
        // an additional next-year occurrence so the user sees "what's coming".
        final entries = <_BirthdayEntry>[];
        for (final t in all) {
          final m = t.birthMonth!;
          final d = t.birthDay!;
          final thisYear = _safeDate(today.year, m, d);
          final nextYear = _safeDate(today.year + 1, m, d);
          if (!thisYear.isBefore(today)) {
            entries.add(_BirthdayEntry(t, thisYear));
            // Also surface next-year iteration so the user can see what's
            // coming after the current calendar year.
            entries.add(_BirthdayEntry(t, nextYear));
          } else {
            // Already passed this year — show next-year iteration only.
            entries.add(_BirthdayEntry(t, nextYear));
          }
        }
        entries.sort((a, b) => a.date.compareTo(b.date));

        // Group consecutive entries by year so we can insert a year separator.
        final widgets = <Widget>[];
        int? lastYear;
        for (final e in entries) {
          if (e.date.year != lastYear) {
            widgets.add(_YearHeader(year: e.date.year));
            lastYear = e.date.year;
          }
          widgets.add(
            Dismissible(
              key: ValueKey('bday_${e.task.id}_${e.date.year}'),
              direction: DismissDirection.endToStart,
              background: const TaskDeleteBackground(),
              onDismissed: (_) {
                final savedListId = e.task.listId;
                taskController.deleteTask(e.task.id);
                UndoScope.maybeOf(context)?.show(
                  label: S.of(context).taskTrashedToast,
                  onUndo: () =>
                      taskController.restoreTask(e.task.id, savedListId),
                );
              },
              child: BirthdayRow(
                task: e.task,
                celebrationDate: e.date,
                onToggle: () => taskController.toggleCompleted(e.task.id),
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    settings: const RouteSettings(
                        name: TaskDetailView.routeName),
                    builder: (_) => TaskDetailView(
                      task: e.task,
                      controller: taskController,
                      folderController: folderController,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: widgets,
        );
      },
    );
  }

  /// Returns a valid DateTime at midnight for the given y/m/d, clamping the
  /// day to the last day of the month when Feb 29 is requested in a
  /// non-leap year.
  static DateTime _safeDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }
}

class _BirthdayEntry {
  const _BirthdayEntry(this.task, this.date);
  final Task task;
  final DateTime date;
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        '$year',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
