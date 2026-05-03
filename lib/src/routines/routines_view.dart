import 'package:flutter/cupertino.dart';

import '../models/routine.dart';
import 'routine_controller.dart';
import 'routine_creation_view.dart';
import 'routine_icons.dart';

class RoutinesView extends StatelessWidget {
  const RoutinesView({super.key, required this.controller});

  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Routines'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final routines = controller.todayRoutines;
            if (routines.isEmpty) {
              return _EmptyState(
                onAdd: () =>
                    showRoutineCreationView(context, controller),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _RoutineRow(
                      routine: routines[index],
                      controller: controller,
                    ),
                    childCount: routines.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.arrow_2_circlepath,
            size: 56,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No routines today',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first routine',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.controller});

  final Routine routine;
  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    final isCompleted = controller.isTodayCompleted(routine);
    final progress = controller.todayProgress(routine.id);

    return Dismissible(
      key: ValueKey(routine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.delete,
            color: CupertinoColors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await _confirmDelete(context);
      },
      onDismissed: (_) => controller.deleteRoutine(routine.id),
      child: GestureDetector(
        onTap: () => controller.recordProgress(routine),
        onLongPress: () => _showOptions(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              _RoutineIcon(
                routine: routine,
                isCompleted: isCompleted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  routine.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : CupertinoColors.label.resolveFrom(context),
                    decoration: isCompleted && routine.goalType == 'achieve_all'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (routine.goalType == 'certain_amount') ...[
                const SizedBox(width: 8),
                _ProgressBadge(
                  progress: progress,
                  goal: routine.goalAmount ?? 1,
                  unit: routine.goalUnit ?? '',
                  isCompleted: isCompleted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Delete Routine'),
            content: Text(
                'Delete "${routine.name}"? This will also remove all recorded history.'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: const Text('Delete'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showOptions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => RoutineCreationView(
                    controller: controller,
                    existing: routine,
                  ),
                ),
              );
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              final ok = await _confirmDelete(context);
              if (ok) controller.deleteRoutine(routine.id);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _RoutineIcon extends StatelessWidget {
  const _RoutineIcon({required this.routine, required this.isCompleted});

  final Routine routine;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCompleted
            ? Color(routine.iconColor).withOpacity(0.5)
            : Color(routine.iconColor),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCompleted && routine.goalType == 'achieve_all'
            ? CupertinoIcons.checkmark
            : routineIconData(routine.iconId),
        color: CupertinoColors.white,
        size: 20,
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.progress,
    required this.goal,
    required this.unit,
    required this.isCompleted,
  });

  final int progress;
  final int goal;
  final String unit;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF34C759).withOpacity(0.15)
            : CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$progress/$goal${unit.isNotEmpty ? ' $unit' : ''}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isCompleted
              ? const Color(0xFF34C759)
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
