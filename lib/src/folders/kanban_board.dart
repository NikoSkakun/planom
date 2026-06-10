import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../models/view_mode.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/task_row.dart';
import '../theme/app_theme.dart';
import '../utils/plus_drag_payload.dart';

/// A group of tasks shown inside a Kanban column. A column may contain several
/// groups: an implicit headerless "top" group, one collapsible group per list
/// section, and an implicit collapsible "Completed" group at the bottom.
class KanbanGroupData {
  const KanbanGroupData({
    required this.id,
    required this.tasks,
    this.title,
    this.isCompleted = false,
    this.sectionId,
  });

  /// Stable unique id (used as the collapse-state key + Plus-drop token).
  final String id;

  /// `null` for the headerless top group; otherwise the section / "Completed"
  /// label rendered as a collapsible header.
  final String? title;
  final List<Task> tasks;

  /// Completed groups default to collapsed and aren't Plus-drop targets.
  final bool isCompleted;

  /// The section a Plus-button drop here should assign the new task to
  /// (`null` = no section / top group).
  final String? sectionId;
}

/// One column of a [KanbanBoard]. [id] is an opaque token handed back to
/// [KanbanBoard.onMoveTask] when a card is dropped here, and to the create
/// callbacks when the Plus button targets this column.
class KanbanColumnData {
  const KanbanColumnData({
    required this.id,
    required this.title,
    required this.groups,
    this.accentColor,
  });

  final String id;
  final String title;
  final List<KanbanGroupData> groups;
  final Color? accentColor;

  /// Count of uncompleted tasks across all non-completed groups.
  int get activeCount => groups
      .where((g) => !g.isCompleted)
      .fold(0, (sum, g) => sum + g.tasks.where((t) => !t.isCompleted).length);
}

/// Lets a host read the Kanban board's currently focused column and request a
/// snap-to it. Attach via [KanbanBoard.boardController] (like a ScrollController).
class KanbanBoardController {
  _KanbanBoardState? _state;

  void _attach(_KanbanBoardState s) => _state = s;
  void _detach(_KanbanBoardState s) {
    if (identical(_state, s)) _state = null;
  }

  /// Id of the column currently centered (snap) or nearest the viewport start
  /// (free). `null` when no board is attached / there are no columns.
  String? get focusedColumnId => _state?.focusedColumnId;

  /// Animates the board so the focused column is aligned. A no-op in snap mode
  /// (already aligned); in free mode it scrolls the nearest column into place.
  Future<void> snapToFocused() async => _state?.snapToFocused();
}

/// Horizontally-scrolling Kanban board. Columns render their tasks as cards
/// that can be long-pressed and dragged onto another column. The board also
/// accepts the global Plus button as a drop target (per column / per section
/// group) and supports free or snap (paged) horizontal scrolling.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({
    super.key,
    required this.columns,
    required this.onMoveTask,
    required this.onTapTask,
    required this.onToggleTask,
    this.scrollMode = KanbanScrollMode.snap,
    this.boardController,
    this.onCreateInColumn,
    this.onCreateInGroup,
    this.onReorderTask,
    this.emptyLabel,
  });

  final List<KanbanColumnData> columns;
  final void Function(String taskId, String toColumnId) onMoveTask;
  final void Function(Task task) onTapTask;
  final void Function(Task task) onToggleTask;
  final KanbanScrollMode scrollMode;
  final KanbanBoardController? boardController;

  /// Plus button dropped on a column's body (or tapped while this column is
  /// focused). [columnId] is the column's opaque id.
  final void Function(String columnId)? onCreateInColumn;

  /// Plus button dropped on a specific section group inside a column.
  final void Function(String columnId, KanbanGroupData group)? onCreateInGroup;

  /// A card was dropped between cards (within or across groups/columns) to
  /// reorder it. [beforeTaskId] is the task it should land before (null = end
  /// of the group). The host resolves [columnId] + [group] to a list/section.
  final void Function(
    String columnId,
    KanbanGroupData group,
    String movedTaskId,
    String? beforeTaskId,
  )? onReorderTask;

  final String? emptyLabel;

  /// Column width in free-scroll mode.
  static const double _freeColumnWidth = 320;

  /// Fraction of the viewport one page occupies in snap mode — under 1 so the
  /// neighbouring columns peek at both edges (the page is centred via
  /// `padEnds: true`) as a swipe affordance.
  static const double _snapViewportFraction = 0.92;

  /// Bottom padding inside a column's scroll list so the last cards can scroll
  /// clear of the floating + button (which now draws over the column).
  static const double _columnBottomInset = 88;

  /// Small gap below each column so its rounded bottom edge doesn't touch the
  /// tab bar. The + button still overlaps the column's lower portion.
  static const double _columnBottomGap = 12;

  /// Horizontal distance from the board's left/right edge that triggers an
  /// auto-scroll to the adjacent column when a card is dragged into that
  /// margin. Big enough to be easy to hit with a thumb on the move.
  static const double _edgeScrollMargin = 72;

  /// Interval between auto-paging steps while the dragged card stays inside
  /// the edge margin. Tuned so adjacent columns flip past at a readable but
  /// purposeful pace.
  static const Duration _edgeScrollInterval = Duration(milliseconds: 600);

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  // Collapse state lives in the board (ephemeral across rebuilds, keyed by the
  // stable group id). Sections default expanded; completed groups default
  // collapsed.
  final Set<String> _collapsedSections = {};
  final Set<String> _expandedCompleted = {};

  // Free-scroll mode uses a plain ScrollController; snap mode uses a
  // PageController. Only one is non-null at a time.
  ScrollController? _scrollController;
  PageController? _pageController;
  int _focusedIndex = 0;

  // Edge-scroll state while a card is being dragged. The timer ticks once per
  // [_edgeScrollInterval] while the pointer stays inside the left/right
  // margin, paging the board one column toward that edge until either the
  // pointer leaves the margin or the board reaches its end.
  Timer? _edgeScrollTimer;
  int _edgeScrollDirection = 0; // -1 left, +1 right, 0 idle
  bool _autoScrolling = false;

  @override
  void initState() {
    super.initState();
    _initScrollers();
    widget.boardController?._attach(this);
  }

  void _initScrollers() {
    if (widget.scrollMode == KanbanScrollMode.snap) {
      _pageController =
          PageController(viewportFraction: KanbanBoard._snapViewportFraction)
            ..addListener(_onPageScroll);
    } else {
      _scrollController = ScrollController()..addListener(_onFreeScroll);
    }
  }

  @override
  void didUpdateWidget(KanbanBoard old) {
    super.didUpdateWidget(old);
    if (old.boardController != widget.boardController) {
      old.boardController?._detach(this);
      widget.boardController?._attach(this);
    }
    if (old.scrollMode != widget.scrollMode) {
      _disposeScrollers();
      _initScrollers();
    }
    if (_focusedIndex >= widget.columns.length) {
      _focusedIndex = widget.columns.isEmpty ? 0 : widget.columns.length - 1;
    }
  }

  void _disposeScrollers() {
    _scrollController?.removeListener(_onFreeScroll);
    _scrollController?.dispose();
    _scrollController = null;
    _pageController?.removeListener(_onPageScroll);
    _pageController?.dispose();
    _pageController = null;
  }

  @override
  void dispose() {
    widget.boardController?._detach(this);
    _stopEdgeScroll();
    _disposeScrollers();
    super.dispose();
  }

  void _onCardDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final local = box.globalToLocal(details.globalPosition);
    final width = box.size.width;
    if (width <= 0) return;
    int direction = 0;
    if (local.dx < KanbanBoard._edgeScrollMargin) {
      direction = -1;
    } else if (local.dx > width - KanbanBoard._edgeScrollMargin) {
      direction = 1;
    }
    if (direction == 0) {
      _stopEdgeScroll();
      return;
    }
    if (direction != _edgeScrollDirection) {
      _edgeScrollDirection = direction;
      _edgeScrollTimer?.cancel();
      // Fire immediately so the first column flip happens as soon as the
      // pointer crosses the margin; subsequent flips are paced by the timer.
      _stepEdgeScroll();
      _edgeScrollTimer = Timer.periodic(
        KanbanBoard._edgeScrollInterval,
        (_) => _stepEdgeScroll(),
      );
    }
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
    _edgeScrollDirection = 0;
  }

  Future<void> _stepEdgeScroll() async {
    if (_autoScrolling) return;
    final direction = _edgeScrollDirection;
    if (direction == 0 || widget.columns.isEmpty) return;
    final target = _focusedIndex + direction;
    if (target < 0 || target >= widget.columns.length) {
      _stopEdgeScroll();
      return;
    }
    _autoScrolling = true;
    try {
      if (widget.scrollMode == KanbanScrollMode.snap) {
        await _pageController?.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        await _scrollController?.animateTo(
          target * KanbanBoard._freeColumnWidth,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } finally {
      _autoScrolling = false;
    }
  }

  void _onPageScroll() {
    final page = _pageController?.page;
    if (page == null) return;
    final idx = page.round();
    if (idx != _focusedIndex) setState(() => _focusedIndex = idx);
  }

  void _onFreeScroll() {
    final c = _scrollController;
    if (c == null || !c.hasClients) return;
    final idx =
        (c.offset / KanbanBoard._freeColumnWidth).round().clamp(0, 1 << 30);
    if (idx != _focusedIndex && idx < widget.columns.length) {
      setState(() => _focusedIndex = idx);
    }
  }

  String? get focusedColumnId {
    if (widget.columns.isEmpty) return null;
    final i = _focusedIndex.clamp(0, widget.columns.length - 1);
    return widget.columns[i].id;
  }

  Future<void> snapToFocused() async {
    if (widget.columns.isEmpty) return;
    final i = _focusedIndex.clamp(0, widget.columns.length - 1);
    if (widget.scrollMode == KanbanScrollMode.snap) {
      await _pageController?.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      await _scrollController?.animateTo(
        i * KanbanBoard._freeColumnWidth,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleGroup(KanbanGroupData group) {
    setState(() {
      if (group.isCompleted) {
        if (_expandedCompleted.contains(group.id)) {
          _expandedCompleted.remove(group.id);
        } else {
          _expandedCompleted.add(group.id);
        }
      } else {
        if (_collapsedSections.contains(group.id)) {
          _collapsedSections.remove(group.id);
        } else {
          _collapsedSections.add(group.id);
        }
      }
    });
  }

  bool _isExpanded(KanbanGroupData group) => group.isCompleted
      ? _expandedCompleted.contains(group.id)
      : !_collapsedSections.contains(group.id);

  @override
  Widget build(BuildContext context) {
    if (widget.columns.isEmpty) {
      return Center(
        child: Text(
          widget.emptyLabel ?? S.of(context).noItems,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    Widget columnAt(int index) => _KanbanColumn(
          data: widget.columns[index],
          onMoveTask: widget.onMoveTask,
          onTapTask: widget.onTapTask,
          onToggleTask: widget.onToggleTask,
          onCreateInColumn: widget.onCreateInColumn,
          onCreateInGroup: widget.onCreateInGroup,
          onReorderTask: widget.onReorderTask,
          isExpanded: _isExpanded,
          onToggleGroup: _toggleGroup,
          onCardDragUpdate: _onCardDragUpdate,
          onCardDragEnded: _stopEdgeScroll,
        );

    if (widget.scrollMode == KanbanScrollMode.snap) {
      // `padEnds: true` centres each page so the previous/next columns peek at
      // both edges. A small bottom gap keeps the column's rounded bottom edge
      // off the tab bar while the + button still overlaps its lower portion.
      return PageView.builder(
        controller: _pageController,
        itemCount: widget.columns.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, KanbanBoard._columnBottomGap),
          child: columnAt(index),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, KanbanBoard._columnBottomGap),
      itemCount: widget.columns.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) => SizedBox(
        width: KanbanBoard._freeColumnWidth -
            12, // leave room for the separator/padding
        child: columnAt(index),
      ),
    );
  }
}

/// Column background (the "window-container"). Distinct from the page
/// background in both light and dark — the dark default page bg is `1C1C1E`,
/// so the column uses an elevated grey there to stay visible.
Color _columnColor(BuildContext context) {
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
}

Color _cardColor(BuildContext context) {
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.data,
    required this.onMoveTask,
    required this.onTapTask,
    required this.onToggleTask,
    required this.onCreateInColumn,
    required this.onCreateInGroup,
    required this.onReorderTask,
    required this.isExpanded,
    required this.onToggleGroup,
    required this.onCardDragUpdate,
    required this.onCardDragEnded,
  });

  final KanbanColumnData data;
  final void Function(String taskId, String toColumnId) onMoveTask;
  final void Function(Task task) onTapTask;
  final void Function(Task task) onToggleTask;
  final void Function(String columnId)? onCreateInColumn;
  final void Function(String columnId, KanbanGroupData group)? onCreateInGroup;
  final void Function(
    String columnId,
    KanbanGroupData group,
    String movedTaskId,
    String? beforeTaskId,
  )? onReorderTask;
  final bool Function(KanbanGroupData group) isExpanded;
  final void Function(KanbanGroupData group) onToggleGroup;
  final void Function(DragUpdateDetails details) onCardDragUpdate;
  final VoidCallback onCardDragEnded;

  bool _containsTask(String taskId) =>
      data.groups.any((g) => g.tasks.any((t) => t.id == taskId));

  @override
  Widget build(BuildContext context) {
    final accent = data.accentColor ?? AppColors.accent;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) {
        final v = d.data;
        if (v is PlusDragPayload) return onCreateInColumn != null;
        if (v is String) return !_containsTask(v);
        return false;
      },
      onAcceptWithDetails: (d) {
        final v = d.data;
        if (v is PlusDragPayload) {
          onCreateInColumn?.call(data.id);
        } else if (v is String) {
          onMoveTask(v, data.id);
        }
      },
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: _columnColor(context),
            borderRadius: BorderRadius.circular(14),
            // Border is always 2px wide so toggling the highlight can't reflow
            // the column's contents; only the colour changes. When not a drop
            // target the border is fully transparent (no visible outline), and
            // it turns accent while the Plus button hovers over the column.
            border: Border.all(
              color: highlighted ? accent : const Color(0x00000000),
              width: 2,
            ),
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
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
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
                      '${data.activeCount}',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _columnBody(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _columnBody(BuildContext context) {
    final hasAnyTask = data.groups.any((g) => g.tasks.isNotEmpty);
    if (!hasAnyTask) {
      // Keep the empty column a tall Plus-drop / card-drop target.
      return _GroupDropZone(
        enabled: onCreateInColumn != null,
        onAccept: () => onCreateInColumn?.call(data.id),
        child: const SizedBox(height: double.infinity, width: double.infinity),
      );
    }

    final children = <Widget>[];
    for (final group in data.groups) {
      // Skip empty headerless (top) and empty completed groups; keep empty
      // section headers so a list's sections stay visible in the column.
      if (group.tasks.isEmpty && (group.title == null || group.isCompleted)) {
        continue;
      }
      final expanded = isExpanded(group);
      if (group.title != null) {
        children.add(_GroupHeader(
          group: group,
          expanded: expanded,
          onToggle: () => onToggleGroup(group),
        ));
      }
      if (group.title == null || expanded) {
        final body = _groupBody(group);
        // Section / top groups accept Plus drops; completed groups don't.
        if (!group.isCompleted && onCreateInGroup != null) {
          children.add(_GroupDropZone(
            enabled: true,
            onAccept: () => onCreateInGroup!(data.id, group),
            child: body,
          ));
        } else {
          children.add(body);
        }
      }
    }

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(8, 0, 8, KanbanBoard._columnBottomInset),
      children: children,
    );
  }

  /// Builds the cards for [group]. Active (non-completed) groups get
  /// insert-before drop targets between cards plus a trailing slot so cards can
  /// be long-press-dragged to a new position (mirrors the list view's
  /// drag-to-reorder). Completed groups render plain, non-reorderable cards.
  Widget _groupBody(KanbanGroupData group) {
    final reorderable = !group.isCompleted && onReorderTask != null;
    if (group.tasks.isEmpty) {
      // Keep a small trailing drop slot for empty active groups so a card can
      // be dropped into an otherwise-empty section.
      return reorderable
          ? _KanbanReorderSlot(
              onAccept: (movedId) =>
                  onReorderTask!(data.id, group, movedId, null),
              minHeight: 10,
            )
          : const SizedBox(height: 10, width: double.infinity);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final task in group.tasks)
          if (reorderable)
            _KanbanReorderTarget(
              beforeTaskId: task.id,
              onAccept: (movedId) =>
                  onReorderTask!(data.id, group, movedId, task.id),
              child: _KanbanCard(
                task: task,
                onTap: () => onTapTask(task),
                onToggle: () => onToggleTask(task),
                onDragUpdate: onCardDragUpdate,
                onDragEnded: onCardDragEnded,
              ),
            )
          else
            _KanbanCard(
              task: task,
              onTap: () => onTapTask(task),
              onToggle: () => onToggleTask(task),
              onDragUpdate: onCardDragUpdate,
              onDragEnded: onCardDragEnded,
            ),
        if (reorderable)
          _KanbanReorderSlot(
            onAccept: (movedId) => onReorderTask!(data.id, group, movedId, null),
          ),
      ],
    );
  }
}

/// Insert-before drop target wrapping a card. Accepts a dragged task id and
/// shows a 2 px accent line at the top edge while hovering.
class _KanbanReorderTarget extends StatelessWidget {
  const _KanbanReorderTarget({
    required this.beforeTaskId,
    required this.onAccept,
    required this.child,
  });

  final String beforeTaskId;
  final void Function(String movedTaskId) onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != beforeTaskId,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: highlighted ? 3 : 0,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

/// End-of-group drop target so a card can be dropped after the last card.
class _KanbanReorderSlot extends StatelessWidget {
  const _KanbanReorderSlot({required this.onAccept, this.minHeight = 24});

  final void Function(String movedTaskId) onAccept;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: highlighted ? minHeight + 16 : minHeight,
          width: double.infinity,
          alignment: Alignment.topCenter,
          child: highlighted
              ? Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Wraps a group body in a Plus-button drop target that highlights on hover.
class _GroupDropZone extends StatelessWidget {
  const _GroupDropZone({
    required this.enabled,
    required this.onAccept,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAccept(),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Container(
          decoration: hovering
              ? BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: child,
        );
      },
    );
  }
}

/// Collapsible header for a section / "Completed" group inside a column.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  final KanbanGroupData group;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final count = group.isCompleted
        ? group.tasks.length
        : group.tasks.where((t) => !t.isCompleted).length;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Row(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              turns: expanded ? 0 : -0.25,
              child: Icon(
                CupertinoIcons.chevron_down,
                size: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                group.title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDragUpdate,
    required this.onDragEnded,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final void Function(DragUpdateDetails details) onDragUpdate;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final card = _cardContent(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LongPressDraggable<String>(
        data: task.id,
        delay: const Duration(milliseconds: 300),
        onDragUpdate: onDragUpdate,
        onDragEnd: (_) => onDragEnded(),
        onDraggableCanceled: (_, __) => onDragEnded(),
        onDragCompleted: onDragEnded,
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
          color: _cardColor(context),
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
