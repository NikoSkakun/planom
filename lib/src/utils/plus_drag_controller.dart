import 'package:flutter/widgets.dart';

import 'plus_drag_payload.dart';

/// Optional handlers a tab's content can register so that dropping the
/// global Plus button on a list/folder/day/section opens the right
/// creation flow scoped to that target.
///
/// The home shell creates one of these and exposes it through an
/// InheritedWidget; tabs that care about drag-drop register themselves
/// during build via `PlusDragScope.of(context)`.
class PlusDragController {
  /// Called when the user drops the plus button on a list row. The
  /// receiver should open whichever creation sheet is appropriate for
  /// that list type (regular task, birthday, etc.).
  void Function(String listId)? onDropOnList;

  /// Called when the user drops on a folder row — typically routes to
  /// the folder-add flow scoped to that parent folder.
  void Function(String folderId)? onDropOnFolder;

  /// Called when the user drops on a section header inside a list. The
  /// receiver should create a new task in [listId] assigned to [sectionId].
  void Function(String listId, String sectionId)? onDropOnSection;

  /// Called when the user drops on a calendar day cell. The receiver
  /// should open the calendar's "Task or Event?" picker for [date].
  void Function(DateTime date)? onDropOnDay;

  /// Called when the user drops on a note folder row. The receiver
  /// should create a new note inside that folder.
  void Function(String folderId)? onDropOnNoteFolder;

  /// Called when the user drops on the notes-root area (no folder).
  /// The receiver should create a new root-level note.
  void Function()? onDropOnNotesRoot;
}

class PlusDragScope extends InheritedWidget {
  const PlusDragScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PlusDragController controller;

  static PlusDragController? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PlusDragScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(covariant PlusDragScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Convenience wrapper to mark a widget as a Plus-button drop target.
class PlusDropTarget extends StatelessWidget {
  const PlusDropTarget({
    super.key,
    required this.onAccept,
    required this.child,
  });

  final VoidCallback onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAccept(),
      builder: (context, candidates, _) {
        return Container(
          decoration: candidates.isEmpty
              ? null
              : BoxDecoration(
                  color: const Color(0x33FF4D00),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: child,
        );
      },
    );
  }
}
