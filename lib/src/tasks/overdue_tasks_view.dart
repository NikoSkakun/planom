import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/day_boundary.dart';
import '../utils/fast_route.dart';
import '../utils/selection_checkbox.dart';
import 'calendar_date_picker.dart';
import 'task_controller.dart';

/// Shows the "Overdue Tasks" review as a full-screen modal on the root
/// navigator. Returns once the user dismisses it. No-op when there are no
/// overdue tasks (so callers don't have to pre-check).
Future<void> showOverdueTasksReview(
    BuildContext context, TaskController controller) {
  if (controller.overdueTasks.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    FastRoute<void>(
      fullscreenDialog: true,
      builder: (_) => OverdueTasksView(controller: controller),
    ),
  );
}

/// First-open-of-a-new-day review of uncompleted overdue tasks. The user can
/// postpone everything to today at once, or select specific tasks and either
/// postpone just those or mark them completed (as of yesterday).
class OverdueTasksView extends StatefulWidget {
  const OverdueTasksView({super.key, required this.controller});

  final TaskController controller;

  @override
  State<OverdueTasksView> createState() => _OverdueTasksViewState();
}

class _OverdueTasksViewState extends State<OverdueTasksView> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _postponeAll() async {
    final ids = widget.controller.overdueTasks.map((t) => t.id).toList();
    await widget.controller.postponeTasksToToday(ids);
    _closeIfEmpty();
  }

  Future<void> _postponeSelected() async {
    await widget.controller.postponeTasksToToday(_selected.toList());
    setState(_selected.clear);
    _closeIfEmpty();
  }

  Future<void> _completeSelected() async {
    // Record the completion as of yesterday — these tasks were due in the past.
    final yesterday = DayBoundary.today().subtract(const Duration(days: 1));
    for (final id in _selected.toList()) {
      await widget.controller.markCompletedAt(id, yesterday);
    }
    setState(_selected.clear);
    _closeIfEmpty();
  }

  void _closeIfEmpty() {
    if (!mounted) return;
    if (widget.controller.overdueTasks.isEmpty) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.overdueTasksTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(s.done),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final overdue = widget.controller.overdueTasks;
            // Drop any selection that's no longer overdue (postponed/completed).
            _selected.retainWhere((id) => overdue.any((t) => t.id == id));
            if (overdue.isEmpty) {
              return Center(
                child: Text(
                  s.overdueNone,
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          s.overdueReviewBody,
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ),
                      for (final t in overdue)
                        _OverdueRow(
                          title: t.title,
                          dateLabel: formatTaskDateRelative(
                            context,
                            t.dueDate!,
                            doTime: t.doTime,
                          ),
                          selected: _selected.contains(t.id),
                          onTap: () => _toggle(t.id),
                        ),
                    ],
                  ),
                ),
                _Footer(
                  selectedCount: _selected.length,
                  onPostponeAll: _postponeAll,
                  onPostponeSelected: _postponeSelected,
                  onCompleteSelected: _completeSelected,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  const _OverdueRow({
    required this.title,
    required this.dateLabel,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String dateLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SelectionCheckbox(checked: selected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemRed,
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

class _Footer extends StatelessWidget {
  const _Footer({
    required this.selectedCount,
    required this.onPostponeAll,
    required this.onPostponeSelected,
    required this.onCompleteSelected,
  });

  final int selectedCount;
  final VoidCallback onPostponeAll;
  final VoidCallback onPostponeSelected;
  final VoidCallback onCompleteSelected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hasSelection = selectedCount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSelection) ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: CupertinoColors.tertiarySystemFill
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onCompleteSelected,
                    child: Text(
                      s.completeSelected(selectedCount),
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onPostponeSelected,
                    child: Text(
                      s.postponeSelected(selectedCount),
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: hasSelection
                  ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
                  : AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              onPressed: onPostponeAll,
              child: Text(
                s.postponeAll,
                style: TextStyle(
                  fontSize: 16,
                  color: hasSelection
                      ? CupertinoColors.label.resolveFrom(context)
                      : CupertinoColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
