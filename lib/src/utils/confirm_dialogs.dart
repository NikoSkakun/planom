import 'package:flutter/cupertino.dart';

/// Shows the standard "Move to Trash?" confirmation dialog.
///
/// Returns `true` if the user confirmed, `false` (or `null` → coerced) if they
/// cancelled or dismissed the dialog by tapping outside.
///
/// [name] is interpolated into the title (e.g. `"Move \"Inbox\" to Trash?"`).
/// [body] overrides the default subtitle. When [isFolder] is true, the
/// default body mentions nested contents.
Future<bool> confirmMoveToTrash(
  BuildContext context, {
  required String name,
  String? body,
  bool isFolder = false,
}) async {
  final defaultBody = isFolder
      ? 'This folder and all its contents will be moved to Trash.'
      : 'This item and any related data will be moved to Trash.';
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('Move "$name" to Trash?'),
      content: Text(body ?? defaultBody),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Move to Trash'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a hard-delete confirmation dialog. Used for items (like routines)
/// that are permanently removed rather than soft-deleted into Trash.
Future<bool> confirmHardDelete(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Delete',
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () =>
              Navigator.of(ctx, rootNavigator: true).pop(true),
          child: Text(confirmLabel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  return result == true;
}
