import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';

/// Shows the standard "Move to Trash?" confirmation dialog.
Future<bool> confirmMoveToTrash(
  BuildContext context, {
  required String name,
  String? body,
  bool isFolder = false,
}) async {
  final s = S.of(context);
  final defaultBody = isFolder ? s.moveToTrashFolderBody : s.moveToTrashItemBody;
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(s.moveToTrashQuestion(name)),
      content: Text(body ?? defaultBody),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(s.moveToTrashAction),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.cancel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a hard-delete confirmation dialog.
Future<bool> confirmHardDelete(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
}) async {
  final s = S.of(context);
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
          child: Text(confirmLabel ?? s.delete),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(ctx, rootNavigator: true).pop(false),
          child: Text(s.cancel),
        ),
      ],
    ),
  );
  return result == true;
}
