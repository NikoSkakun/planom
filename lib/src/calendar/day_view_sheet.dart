import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
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
import 'remote_event_detail_view.dart';

Future<void> showDayViewSheet(
  BuildContext context, {
  required DateTime date,
  required TaskController taskController,
  required EventController eventController,
  required FolderController folderController,
  GoogleCalendarController? googleCalendarController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => DayViewSheet(
      date: date,
      taskController: taskController,
      eventController: eventController,
      folderController: folderController,
      googleCalendarController: googleCalendarController,
    ),
  );
}

class DayViewSheet extends StatefulWidget {
  const DayViewSheet({
    super.key,
    required this.date,
    required this.taskController,
    required this.eventController,
    required this.folderController,
    this.googleCalendarController,
  });

  final DateTime date;
  final TaskController taskController;
  final EventController eventController;
  final FolderController folderController;
  final GoogleCalendarController? googleCalendarController;

  @override
  State<DayViewSheet> createState() => _DayViewSheetState();
}

class _DayViewSheetState extends State<DayViewSheet> {
  OverlayEntry? _pickerEntry;

  @override
  void dispose() {
    _pickerEntry?.remove();
    _pickerEntry = null;
    super.dispose();
  }

  void _showAddPicker(BuildContext context) {
    _pickerEntry?.remove();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) {
      void dismiss() {
        if (_pickerEntry == entry) _pickerEntry = null;
        entry.remove();
      }

      return Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: const SizedBox.expand(),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 72,
            right: 20,
            child: _AddPickerMenu(
              onTask: () {
                dismiss();
                showTaskCreationSheet(
                  context,
                  widget.taskController,
                  widget.folderController,
                  initialDueDate: widget.date,
                );
              },
              onEvent: () {
                dismiss();
                showEventCreationSheet(
                  context,
                  widget.eventController,
                  initialDate: widget.date,
                  googleCalendarController: widget.googleCalendarController,
                );
              },
            ),
          ),
        ],
      );
    });
    _pickerEntry = entry;
    overlay.insert(entry);
  }

  void _openTask(Task task) {
    Navigator.of(context).push(
      FastRoute<void>(
        settings: const RouteSettings(name: TaskDetailView.routeName),
        builder: (_) => TaskDetailView(
          task: task,
          controller: widget.taskController,
          folderController: widget.folderController,
        ),
      ),
    );
  }

  void _openEvent(Event event) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => EventDetailView(
          event: event,
          controller: widget.eventController,
        ),
      ),
    );
  }

  void _openRemoteEvent(RemoteEvent event) {
    final c = widget.googleCalendarController;
    if (c == null) return;
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => RemoteEventDetailView(
          event: event,
          controller: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = mq.size.height * 0.78;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final monthsLongList = monthsLong(context);
    final weekdaysLongList = weekdaysLong(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Column(
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
                      '${widget.date.day}',
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
                        '${monthsLongList[widget.date.month - 1]}\n'
                        '${weekdaysLongList[widget.date.weekday - 1]}',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
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
                  listenable: Listenable.merge([
                    widget.taskController,
                    widget.eventController,
                    widget.folderController,
                    if (widget.googleCalendarController != null)
                      widget.googleCalendarController!,
                  ]),
                  builder: (ctx, _) => _buildList(ctx),
                ),
              ),
              SizedBox(height: mq.padding.bottom + 72),
            ],
          ),
          // Floating + button — bottom right
          Positioned(
            bottom: mq.padding.bottom + 16,
            right: 20,
            child: GestureDetector(
              onTap: () => _showAddPicker(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.plus,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final allTasks = widget.taskController.tasksForDate(widget.date);
    final nonBirthdayTasks =
        allTasks.where((t) => !t.isBirthday).toList();
    final birthdays =
        widget.taskController.birthdaysForDate(widget.date);
    final events = widget.eventController.eventsForDate(widget.date);
    final remoteEvents = widget.googleCalendarController
            ?.eventsForDate(widget.date) ??
        const <RemoteEvent>[];

    // Untimed first (tasks then events), then timed sorted by doTime.
    final untimedTasks =
        nonBirthdayTasks.where((t) => t.doTime == null).toList();
    final untimedEvents = events.where((e) => e.doTime == null).toList();
    final untimedRemote =
        remoteEvents.where((e) => e.doTime == null).toList();
    final timedItems = <_TimedItem>[
      for (final t in nonBirthdayTasks.where((t) => t.doTime != null))
        _TimedItem.task(t),
      for (final e in events.where((e) => e.doTime != null))
        _TimedItem.event(e),
      for (final e in remoteEvents.where((e) => e.doTime != null))
        _TimedItem.remoteEvent(e),
    ]..sort((a, b) => a.doTime.compareTo(b.doTime));

    final isEmpty = untimedTasks.isEmpty &&
        untimedEvents.isEmpty &&
        untimedRemote.isEmpty &&
        timedItems.isEmpty &&
        birthdays.isEmpty;

    if (isEmpty) {
      return Center(
        child: Text(
          S.of(context).noTasksOrEvents,
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        for (final b in birthdays) ...[
          _BirthdayCard(
            task: b,
            celebrationDate: widget.date,
            onTap: () => _openTask(b),
          ),
          const SizedBox(height: 8),
        ],
        for (final t in untimedTasks) ...[
          _TaskCard(
            task: t,
            folderController: widget.folderController,
            onTap: () => _openTask(t),
            onToggle: () => widget.taskController.toggleCompleted(t.id),
          ),
          const SizedBox(height: 8),
        ],
        for (final e in untimedEvents) ...[
          _EventCard(event: e, onTap: () => _openEvent(e)),
          const SizedBox(height: 8),
        ],
        for (final e in untimedRemote) ...[
          _RemoteEventCard(event: e, onTap: () => _openRemoteEvent(e)),
          const SizedBox(height: 8),
        ],
        if (timedItems.isNotEmpty &&
            (untimedTasks.isNotEmpty ||
                untimedEvents.isNotEmpty ||
                untimedRemote.isNotEmpty))
          const SizedBox(height: 4),
        for (final item in timedItems) ...[
          if (item.task != null)
            _TaskCard(
              task: item.task!,
              folderController: widget.folderController,
              onTap: () => _openTask(item.task!),
              onToggle: () =>
                  widget.taskController.toggleCompleted(item.task!.id),
            )
          else if (item.event != null)
            _EventCard(event: item.event!, onTap: () => _openEvent(item.event!))
          else
            _RemoteEventCard(
              event: item.remoteEvent!,
              onTap: () => _openRemoteEvent(item.remoteEvent!),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Add picker dropdown ──────────────────────────────────────────────────────

class _AddPickerMenu extends StatelessWidget {
  const _AddPickerMenu({required this.onTask, required this.onEvent});

  final VoidCallback onTask;
  final VoidCallback onEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickerRow(
            label: S.of(context).taskOption,
            icon: CupertinoIcons.checkmark_square,
            onTap: onTask,
          ),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          _PickerRow(
            label: S.of(context).eventOption,
            icon: CupertinoIcons.calendar,
            onTap: onEvent,
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: CupertinoColors.label.resolveFrom(context)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper types ─────────────────────────────────────────────────────────────

class _TimedItem {
  _TimedItem.task(this.task)
      : event = null,
        remoteEvent = null,
        doTime = task!.doTime!;
  _TimedItem.event(this.event)
      : task = null,
        remoteEvent = null,
        doTime = event!.doTime!;
  _TimedItem.remoteEvent(this.remoteEvent)
      : task = null,
        event = null,
        doTime = remoteEvent!.doTime!;

  final Task? task;
  final Event? event;
  final RemoteEvent? remoteEvent;
  final int doTime;
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

  static String _dur(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      color: task.isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (task.doTime != null || task.duration != null)
                    Text(
                      [
                        if (task.doTime != null) formatDoTime(task.doTime!),
                        if (task.duration != null) _dur(task.duration!),
                      ].join(' · '),
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
  static const _pastAccent = Color(0xFF8E8E93);

  static String _dur(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  static bool _isPast(Event event) {
    final now = DateTime.now();
    if (event.doTime != null) {
      final endMinutes = event.doTime! + (event.duration ?? 0);
      return event.date.add(Duration(minutes: endMinutes)).isBefore(now);
    }
    final eventDay =
        DateTime(event.date.year, event.date.month, event.date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDay.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final isPast = _isPast(event);
    final accent = isPast ? _pastAccent : _accent;
    final titleColor = isPast
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ),
            if (event.doTime != null)
              Text(
                event.duration != null
                    ? '${formatDoTime(event.doTime!)} · ${_dur(event.duration!)}'
                    : formatDoTime(event.doTime!),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Birthday card ──────────────────────────────────────────────────────────

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({
    required this.task,
    required this.celebrationDate,
    required this.onTap,
  });

  final Task task;
  final DateTime celebrationDate;
  final VoidCallback onTap;

  static const _accent = Color(0xFFFF2D55);

  @override
  Widget build(BuildContext context) {
    final age = task.birthYear != null
        ? celebrationDate.year - task.birthYear!
        : null;
    final s = S.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _accent, width: 3)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.gift_fill, size: 16, color: _accent),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (age != null)
                    Text(
                      '${s.turns} $age',
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

// ─── Remote (Google Calendar) event card ────────────────────────────────────

class _RemoteEventCard extends StatelessWidget {
  const _RemoteEventCard({required this.event, required this.onTap});

  final RemoteEvent event;
  final VoidCallback onTap;

  static const _pastAccent = Color(0xFF8E8E93);

  static String _dur(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  static bool _isPast(RemoteEvent event) {
    final now = DateTime.now();
    if (event.doTime != null) {
      final endMinutes = event.doTime! + (event.duration ?? 0);
      return event.date.add(Duration(minutes: endMinutes)).isBefore(now);
    }
    final eventDay =
        DateTime(event.date.year, event.date.month, event.date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDay.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final isPast = _isPast(event);
    final accent = isPast ? _pastAccent : Color(event.calendarColor);
    final titleColor = isPast
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ),
                // Small Google "G" badge so the source is obvious in the day view.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            if (event.doTime != null)
              Text(
                event.duration != null
                    ? '${formatDoTime(event.doTime!)} · ${_dur(event.duration!)}'
                    : formatDoTime(event.doTime!),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            Text(
              event.calendarName,
              style: TextStyle(
                fontSize: 10,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hour grid (kept for future use) ─────────────────────────────────────────

// class _HourGrid extends StatelessWidget {
//   const _HourGrid({
//     required this.hourHeight,
//     required this.gutterWidth,
//     required this.timedTasks,
//     required this.timedEvents,
//     required this.folderController,
//     required this.onTaskTap,
//     required this.onEventTap,
//     required this.onTaskToggle,
//   });
//
//   final double hourHeight;
//   final double gutterWidth;
//   final List<Task> timedTasks;
//   final List<Event> timedEvents;
//   final FolderController folderController;
//   final void Function(Task) onTaskTap;
//   final void Function(Event) onEventTap;
//   final void Function(Task) onTaskToggle;
//
//   static const _hours = 24;
//
//   @override
//   Widget build(BuildContext context) {
//     final totalHeight = _hours * hourHeight;
//     final separator = CupertinoColors.separator.resolveFrom(context);
//     final labelColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: SizedBox(
//         height: totalHeight,
//         child: Stack(
//           children: [
//             for (var h = 0; h < _hours; h++)
//               Positioned(
//                 top: h * hourHeight,
//                 left: 0,
//                 right: 0,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(
//                       width: gutterWidth,
//                       child: Text(
//                         _hourLabel(h),
//                         textAlign: TextAlign.right,
//                         style: TextStyle(fontSize: 11, color: labelColor),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Container(
//                         height: 0.5,
//                         color: separator,
//                         margin: const EdgeInsets.only(top: 6),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             for (final e in timedEvents)
//               _positionedItem(e.doTime!, e.duration ?? 60,
//                   _EventCard(event: e, onTap: () => onEventTap(e))),
//             for (final t in timedTasks)
//               _positionedItem(t.doTime!, 30,
//                   _TaskCard(
//                     task: t,
//                     folderController: folderController,
//                     onTap: () => onTaskTap(t),
//                     onToggle: () => onTaskToggle(t),
//                   )),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _positionedItem(int doTime, int durationMin, Widget child) {
//     final top = (doTime / 60.0) * hourHeight;
//     final h = (durationMin / 60.0) * hourHeight;
//     return Positioned(
//       top: top,
//       left: gutterWidth + 8,
//       right: 0,
//       height: h.clamp(28.0, double.infinity),
//       child: Padding(padding: const EdgeInsets.only(bottom: 2), child: child),
//     );
//   }
//
//   String _hourLabel(int h) {
//     if (h == 0) return '12 AM';
//     if (h == 12) return '12 PM';
//     return h < 12 ? '$h AM' : '${h - 12} PM';
//   }
// }
