import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

/// Typed payload for a long-press-reorder drag. Distinct payloads keep
/// folder, list, and note drags from accidentally matching each other's
/// DragTargets when several lists share the same screen.
class ReorderDragData<T> {
  const ReorderDragData(this.kind, this.id);
  final T kind;
  final String id;
}

enum ReorderKind { folder, list, noteFolder, note }

/// Identifies the single insertion point of an in-flight task reorder. There
/// is exactly one gap on screen at a time and it is described by this value
/// (records compare structurally, so equality checks are exact and cheap):
///   • `kind == 'before'` → the gap sits above the row whose id is [beforeId];
///   • `kind == 'end'`    → the gap sits at the end of (`listId`, `sectionId`).
typedef ReorderTarget = ({
  String kind,
  String? beforeId,
  String? listId,
  String? sectionId,
});

/// Tracks the currently-dragged reorderable row so drop zones can render a
/// blank placeholder of the right height (the same size the dragged row will
/// occupy after the drop). One drag is in flight at a time across the app —
/// folders, lists, note folders, and tasks all share this notifier so a
/// folder drag doesn't accidentally puff up note-folder drop zones.
class ReorderDragNotifier extends ChangeNotifier {
  ReorderDragNotifier._();
  static final ReorderDragNotifier instance = ReorderDragNotifier._();

  String? _draggingId;
  Object? _draggingKind;
  double _draggingHeight = 0;
  ReorderTarget? _target;

  String? get draggingId => _draggingId;
  Object? get draggingKind => _draggingKind;
  double get draggingHeight => _draggingHeight;
  bool get isDragging => _draggingId != null;

  /// The single active insertion point for a task reorder (null until the
  /// dragged row reports its origin). Used to render exactly one gap.
  ReorderTarget? get target => _target;

  void start(String id, Object kind, double height) {
    _draggingId = id;
    _draggingKind = kind;
    _draggingHeight = height;
    notifyListeners();
  }

  /// Moves the single reorder gap. No-ops (and skips the rebuild) when the
  /// target is unchanged so the high-frequency `onMove` stream stays cheap.
  void setTarget(ReorderTarget? next) {
    if (_target == next) return;
    _target = next;
    notifyListeners();
  }

  void end() {
    if (_draggingId == null) return;
    _draggingId = null;
    _draggingKind = null;
    _draggingHeight = 0;
    _target = null;
    notifyListeners();
  }
}

const Duration _kReorderAnim = Duration(milliseconds: 160);
const Curve _kReorderCurve = Curves.easeOut;
const double _kFallbackRowHeight = 56;

/// Wraps a row in a LongPressDraggable that mimics the iOS reorder visual:
/// the row lifts under the finger as a floating Material card with a shadow,
/// while the original slot collapses to zero height (animated). The list
/// around it smoothly shifts up to fill the gap; the matching drop zone
/// makes room of the same height where the row will land.
class ReorderableRow extends StatefulWidget {
  const ReorderableRow({
    super.key,
    required this.label,
    required this.id,
    required this.kind,
    required this.child,
    this.enabled = true,
  });

  final String label;
  final String id;
  final ReorderKind kind;
  final Widget child;
  final bool enabled;

  @override
  State<ReorderableRow> createState() => _ReorderableRowState();
}

class _ReorderableRowState extends State<ReorderableRow> {
  final GlobalKey _measureKey = GlobalKey();

  double _measureHeight() {
    final ctx = _measureKey.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return _kFallbackRowHeight;
  }

  void _onDragStarted() {
    ReorderDragNotifier.instance
        .start(widget.id, widget.kind, _measureHeight());
  }

  void _onDragEnded() {
    ReorderDragNotifier.instance.end();
  }

  @override
  void dispose() {
    // Defensive: if the drag is still in flight when this widget is
    // disposed (e.g. its list was rebuilt), clear the notifier so the
    // placeholder doesn't get stuck on a future frame.
    if (ReorderDragNotifier.instance.draggingId == widget.id) {
      ReorderDragNotifier.instance.end();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedSize(
      duration: _kReorderAnim,
      curve: _kReorderCurve,
      alignment: Alignment.topCenter,
      child: LongPressDraggable<ReorderDragData<ReorderKind>>(
        data: ReorderDragData(widget.kind, widget.id),
        delay: const Duration(milliseconds: 400),
        onDragStarted: _onDragStarted,
        onDragEnd: (_) => _onDragEnded(),
        onDraggableCanceled: (_, __) => _onDragEnded(),
        onDragCompleted: _onDragEnded,
        // Render the row itself as the drag feedback so the lifted card
        // looks identical to the row it came from (same icon, count,
        // chevron, spacing). The original slot still collapses to zero
        // beneath it so the list closes the gap.
        feedback: _dragFeedback(context, width, widget.child),
        childWhenDragging: const SizedBox.shrink(),
        child: KeyedSubtree(key: _measureKey, child: widget.child),
      ),
    );
  }
}

/// Shared lifted-card scaffolding for reorder drag feedback widgets.
/// Wraps [child] in a Material layer (required because drags render in
/// the root overlay) with the system background and a soft shadow so the
/// row reads as picked up while staying visually identical to the source.
///
/// Two things otherwise make the lifted card diverge from its source row,
/// because the feedback renders in the root [Overlay] — above the per-route
/// `MediaQuery`, and inside a fresh `Material`:
///   • text scale — the root overlay misses the per-route `MediaQuery` that
///     carries the user's text scale, so we re-supply it;
///   • font — `Material` injects its own `DefaultTextStyle`/`IconTheme` (the
///     Material default font, which renders larger with wider letter-spacing),
///     overriding the app's Cupertino Google-font default the in-list rows
///     inherit. We re-assert the source row's `DefaultTextStyle`/`IconTheme`
///     *inside* the Material so the title and note line are a pixel-perfect
///     mirror of the origin.
Widget _dragFeedback(BuildContext context, double width, Widget child) {
  final defaultTextStyle = DefaultTextStyle.of(context);
  final iconTheme = IconTheme.of(context);
  return MediaQuery(
    data: MediaQuery.of(context),
    child: Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: defaultTextStyle.style,
        textAlign: defaultTextStyle.textAlign,
        softWrap: defaultTextStyle.softWrap,
        overflow: defaultTextStyle.overflow,
        maxLines: defaultTextStyle.maxLines,
        textWidthBasis: defaultTextStyle.textWidthBasis,
        textHeightBehavior: defaultTextStyle.textHeightBehavior,
        child: IconTheme(
          data: iconTheme,
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Public version of [_dragFeedback] for use by other reorder sites
/// (task rows, note rows) so the lifted visual stays consistent
/// app-wide.
Widget buildReorderDragFeedback(
    BuildContext context, double width, Widget child) {
  return _dragFeedback(context, width, child);
}

/// DragTarget paired with [ReorderableRow]: when the user drops onto this
/// row, the dropped row is reordered to come immediately before [beforeId].
/// Set [beforeId] to null to drop at the end of the list.
///
/// While a compatible drag hovers, the zone grows by the dragged row's
/// height — pushing this row (and everything below it) down to make room.
class ReorderableDropZone extends StatelessWidget {
  const ReorderableDropZone({
    super.key,
    required this.kind,
    required this.beforeId,
    required this.onReorder,
    required this.child,
  });

  final ReorderKind kind;
  final String? beforeId;
  final void Function(String movedId, String? beforeId) onReorder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ReorderDragData<ReorderKind>>(
      onWillAcceptWithDetails: (d) =>
          d.data.kind == kind && d.data.id != beforeId,
      onAcceptWithDetails: (d) => onReorder(d.data.id, beforeId),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedBuilder(
          animation: ReorderDragNotifier.instance,
          builder: (context, _) {
            final placeholder = highlighted
                ? ReorderDragNotifier.instance.draggingHeight
                : 0.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: _kReorderAnim,
                  curve: _kReorderCurve,
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: placeholder, width: double.infinity),
                ),
                child,
              ],
            );
          },
        );
      },
    );
  }
}

/// Trailing slot at the end of a reorderable list — accepts a drop and
/// places the dropped row at the end. Collapses to zero height when idle
/// so the list flows continuously into whatever follows it (a divider,
/// the next section); on hover, expands to the dragged row's full height
/// so the user sees the same blank space they'd see if they dropped
/// above any other row.
class ReorderableTrailingSlot extends StatelessWidget {
  const ReorderableTrailingSlot({
    super.key,
    required this.kind,
    required this.onReorder,
  });

  final ReorderKind kind;
  final void Function(String movedId) onReorder;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ReorderDragData<ReorderKind>>(
      onWillAcceptWithDetails: (d) => d.data.kind == kind,
      onAcceptWithDetails: (d) => onReorder(d.data.id),
      builder: (context, candidates, _) {
        return AnimatedBuilder(
          animation: ReorderDragNotifier.instance,
          builder: (context, _) {
            final hovering = candidates.isNotEmpty;
            // Only takes up vertical space while a matching drag is
            // actually in flight, so the list flows continuously into
            // whatever follows it (a divider, the next section) when
            // the user is just browsing.
            final dragging = ReorderDragNotifier.instance.isDragging &&
                ReorderDragNotifier.instance.draggingKind == kind;
            final double height;
            if (hovering) {
              height = ReorderDragNotifier.instance.draggingHeight;
            } else if (dragging) {
              height = 16;
            } else {
              height = 0;
            }
            return AnimatedSize(
              duration: _kReorderAnim,
              curve: _kReorderCurve,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
                width: double.infinity,
              ),
            );
          },
        );
      },
    );
  }
}
