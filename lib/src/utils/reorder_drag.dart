import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;

import '../theme/app_theme.dart';

/// Typed payload for a long-press-reorder drag. Distinct payloads keep
/// folder, list, and note drags from accidentally matching each other's
/// DragTargets when several lists share the same screen.
class ReorderDragData<T> {
  const ReorderDragData(this.kind, this.id);
  final T kind;
  final String id;
}

enum ReorderKind { folder, list, noteFolder, note }

/// Wraps a row in a LongPressDraggable that mimics the task-reorder
/// visual: the row lifts under the finger as a floating Material card
/// with a shadow, while the original slot fades in place. Used by the
/// folder, list, and note rows so all reorderable surfaces look the same.
class ReorderableRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return LongPressDraggable<ReorderDragData<ReorderKind>>(
      data: ReorderDragData(kind, id),
      delay: const Duration(milliseconds: 400),
      feedback: Material(
        color: const Color(0x00000000),
        child: Container(
          width: MediaQuery.sizeOf(context).width - 32,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label.isEmpty ? '—' : label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }
}

/// DragTarget paired with [ReorderableRow]: when the user drops onto this
/// row, the dropped row is reordered to come immediately before [beforeId].
/// Set [beforeId] to null to drop at the end of the list.
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
        return Stack(
          children: [
            child,
            if (highlighted)
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Trailing slot at the end of a reorderable list — accepts a drop and
/// places the dropped row at the end. Renders empty (just height) when
/// nothing is hovering and the insert bar otherwise.
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
        return SizedBox(
          height: 12,
          child: candidates.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
