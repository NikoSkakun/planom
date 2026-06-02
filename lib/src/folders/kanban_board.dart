import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/task_row.dart';
import '../theme/app_theme.dart';

/// One column of a [KanbanBoard]. [id] is an opaque token handed back to
/// [KanbanBoard.onMoveTask] when a card is dropped here; the host maps it to a
/// list id / section id as appropriate.
class KanbanColumnData {
  const KanbanColumnData({
    required this.id,
    required this.title,
    required this.tasks,
    this.accentColor,
  });

  final String id;
  final String title;
  final List<Task> tasks;
  final Color? accentColor;
}

/// Horizontally-scrolling Kanban board. Each column renders its tasks as cards
/// that can be long-pressed and dragged onto another column. Dropping a card
/// invokes [onMoveTask] with the dragged task id and the destination column id.
class KanbanBoard extends StatelessWidget {
  const KanbanBoard({
    super.key,
    required this.columns,
    required this.onMoveTask,
    required this.onTapTask,
    required this.onToggleTask,
    this.emptyLabel,
  });

  final List<KanbanColumnData> columns;
  final void Function(String taskId, String toColumnId) onMoveTask;
  final void Function(Task task) onTapTask;
  final void Function(Task task) onToggleTask;
  final String? emptyLabel;

  static const double _columnWidth = 280;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) {
      return Center(
        child: Text(
          emptyLabel ?? S.of(context).noItems,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: columns.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return SizedBox(
          width: _columnWidth,
          child: _KanbanColumn(
            data: columns[index],
            onMoveTask: onMoveTask,
            onTapTask: onTapTask,
            onToggleTask: onToggleTask,
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.data,
    required this.onMoveTask,
    required this.onTapTask,
    required this.onToggleTask,
  });

  final KanbanColumnData data;
  final void Function(String taskId, String toColumnId) onMoveTask;
  final void Function(Task task) onTapTask;
  final void Function(Task task) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final accent = data.accentColor ?? AppColors.accent;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => !data.tasks.any((t) => t.id == d.data),
      onAcceptWithDetails: (d) => onMoveTask(d.data, data.id),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
            border: highlighted
                ? Border.all(color: accent, width: 2)
                : Border.all(color: CupertinoColors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data.tasks.where((t) => !t.isCompleted).length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: data.tasks.isEmpty
                    ? const _EmptyColumnBody()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                        itemCount: data.tasks.length,
                        itemBuilder: (context, i) {
                          final task = data.tasks[i];
                          return _KanbanCard(
                            task: task,
                            onTap: () => onTapTask(task),
                            onToggle: () => onToggleTask(task),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Keeps an empty column tall enough to be an easy drop target.
class _EmptyColumnBody extends StatelessWidget {
  const _EmptyColumnBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: double.infinity, width: double.infinity);
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final card = _cardContent(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LongPressDraggable<String>(
        data: task.id,
        delay: const Duration(milliseconds: 300),
        feedback: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: 264,
            child: _cardContent(context, lifted: true),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      ),
    );
  }

  Widget _cardContent(BuildContext context, {bool lifted = false}) {
    final dueDate = task.dueDate;
    final dateLabel = dueDate != null
        ? formatTaskDateRelative(context, dueDate, doTime: task.doTime)
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
          boxShadow: lifted
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 1),
                child: RoundedCheckbox(
                  checked: task.isCompleted,
                  priority: task.priority,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      color: task.isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : null,
                    ),
                  ),
                  if (task.note != null && task.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        task.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ),
                  if (dateLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
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
