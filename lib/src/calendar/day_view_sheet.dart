import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_creation_sheet.dart';
import '../tasks/task_detail_view.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import 'event_controller.dart';
import 'event_creation_sheet.dart';
import 'event_detail_view.dart';

/// Modal day view: a vertical timeline showing tasks and events for [date].
/// Untimed items are listed at the top; timed items are placed at their time.
void showDayViewSheet(
  BuildContext context, {
  required DateTime date,
  required TaskController taskController,
  required EventController eventController,
  required FolderController folderController,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => DayViewSheet(
      date: date,
      taskController: taskController,
      eventController: eventController,
      folderController: folderController,
    ),
  );
}

class DayViewSheet extends StatelessWidget {
  const DayViewSheet({
    super.key,
    required this.date,
    required this.taskController,
    required this.eventController,
    required this.folderController,
  });

  final DateTime date;
  final TaskController taskController;
  final EventController eventController;
  final FolderController folderController;

  static const _hourHeight = 60.0;
  static const _gutterWidth = 56.0;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = mq.size.height * 0.78;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_months[date.month - 1]}\n${_weekdays[date.weekday - 1]}',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showAddPicker(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.plus,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge(
                  [taskController, eventController, folderController]),
              builder: (ctx, _) => _buildTimeline(ctx),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final tasks = taskController.tasksForDate(date);
    final events = eventController.eventsForDate(date);

    final untimedTasks = tasks.where((t) => t.doTime == null).toList();
    final untimedEvents = events.where((e) => e.doTime == null).toList();
    final timedTasks = tasks.where((t) => t.doTime != null).toList();
    final timedEvents = events.where((e) => e.doTime != null).toList();

    final hasUntimed = untimedTasks.isNotEmpty || untimedEvents.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUntimed) ...[
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(
                'Untimed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: CupertinoColors.secondaryLabel
                      .resolveFrom(context),
                ),
              ),
            ),
            for (final t in untimedTasks)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: _TaskCard(
                  task: t,
                  folderController: folderController,
                  onTap: () => _openTask(context, t),
                  onToggle: () => taskController.toggleCompleted(t.id),
                ),
              ),
            for (final e in untimedEvents)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: _EventCard(
                  event: e,
                  onTap: () => _openEvent(context, e),
                ),
              ),
            const SizedBox(height: 8),
          ],
          _HourGrid(
            hourHeight: _hourHeight,
            gutterWidth: _gutterWidth,
            timedTasks: timedTasks,
            timedEvents: timedEvents,
            folderController: folderController,
            onTaskTap: (t) => _openTask(context, t),
            onEventTap: (e) => _openEvent(context, e),
            onTaskToggle: (t) => taskController.toggleCompleted(t.id),
          ),
        ],
      ),
    );
  }

  void _openTask(BuildContext context, Task task) {
    Navigator.of(context).push(
      FastRoute<void>(
        settings: const RouteSettings(name: TaskDetailView.routeName),
        builder: (_) => TaskDetailView(
          task: task,
          controller: taskController,
          folderController: folderController,
        ),
      ),
    );
  }

  void _openEvent(BuildContext context, Event event) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => EventDetailView(
          event: event,
          controller: eventController,
        ),
      ),
    );
  }

  void _showAddPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add to this day'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showTaskCreationSheet(
                context,
                taskController,
                folderController,
                initialDueDate: date,
              );
            },
            child: const Text('Task'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showEventCreationSheet(
                context,
                eventController,
                initialDate: date,
              );
            },
            child: const Text('Event'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ─── Hour grid ────────────────────────────────────────────────────────────────

class _HourGrid extends StatelessWidget {
  const _HourGrid({
    required this.hourHeight,
    required this.gutterWidth,
    required this.timedTasks,
    required this.timedEvents,
    required this.folderController,
    required this.onTaskTap,
    required this.onEventTap,
    required this.onTaskToggle,
  });

  final double hourHeight;
  final double gutterWidth;
  final List<Task> timedTasks;
  final List<Event> timedEvents;
  final FolderController folderController;
  final void Function(Task) onTaskTap;
  final void Function(Event) onEventTap;
  final void Function(Task) onTaskToggle;

  static const _hours = 24;

  @override
  Widget build(BuildContext context) {
    final totalHeight = _hours * hourHeight;
    final separator = CupertinoColors.separator.resolveFrom(context);
    final labelColor =
        CupertinoColors.tertiaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // Hour lines + labels
            for (var h = 0; h < _hours; h++)
              Positioned(
                top: h * hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: gutterWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Text(
                          _hourLabel(h),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11, color: labelColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                          height: 0.5,
                          color: separator,
                          margin: const EdgeInsets.only(top: 6)),
                    ),
                  ],
                ),
              ),
            // Timed events
            for (final e in timedEvents)
              _positionedItem(
                e.doTime!,
                e.duration ?? 60,
                _EventCard(event: e, onTap: () => onEventTap(e)),
              ),
            // Timed tasks
            for (final t in timedTasks)
              _positionedItem(
                t.doTime!,
                30,
                _TaskCard(
                  task: t,
                  folderController: folderController,
                  onTap: () => onTaskTap(t),
                  onToggle: () => onTaskToggle(t),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _positionedItem(int doTime, int durationMin, Widget child) {
    final top = (doTime / 60.0) * hourHeight;
    final h = (durationMin / 60.0) * hourHeight;
    return Positioned(
      top: top,
      left: gutterWidth + 8,
      right: 0,
      height: h.clamp(28.0, double.infinity),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: child,
      ),
    );
  }

  String _hourLabel(int h) {
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }
}

// ─── Task / Event cards ──────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.folderController,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final FolderController folderController;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final listColor = task.listId != null
        ? folderController.listById(task.listId!)?.color
        : null;
    final accent = listColor != null ? Color(listColor) : AppColors.accent;
    final bg = task.isCompleted
        ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
        : accent.withOpacity(0.12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: task.isCompleted ? accent : null,
                  border: task.isCompleted
                      ? null
                      : Border.all(color: accent, width: 1.5),
                ),
                child: task.isCompleted
                    ? const Icon(CupertinoIcons.checkmark,
                        size: 12, color: CupertinoColors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? CupertinoColors.secondaryLabel
                              .resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (task.doTime != null)
                    Text(
                      formatDoTime(task.doTime!),
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  static const _accent = Color(0xFF0A84FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (event.doTime != null)
              Text(
                event.duration != null
                    ? '${formatDoTime(event.doTime!)} · ${_dur(event.duration!)}'
                    : formatDoTime(event.doTime!),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel
                      .resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _dur(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }
}
