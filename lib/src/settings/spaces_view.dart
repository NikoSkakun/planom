import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';

class SpacesView extends StatelessWidget {
  const SpacesView({super.key});

  Future<void> _addSpace(BuildContext context, SpaceManager mgr) async {
    final s = S.of(context);
    final ctrl = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.newSpace),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: s.spaceName,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop(name);
            },
            child: Text(s.create),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) await mgr.addSpace(result);
  }

  Future<void> _renameSpace(BuildContext context, SpaceManager mgr,
      String id, String currentName) async {
    final s = S.of(context);
    final ctrl = TextEditingController(text: currentName);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.rename),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: s.spaceName,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop(name);
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) await mgr.renameSpace(id, result);
  }

  Future<void> _confirmDelete(
      BuildContext context, SpaceManager mgr, String id) async {
    final s = S.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.deleteSpace),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(s.deleteSpaceBody),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) await mgr.deleteSpace(id);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mgr = SpaceManagerProvider.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.spaces),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: mgr,
          builder: (context, _) {
            final spaces = mgr.spaces;
            final activeId = mgr.activeSpaceId;
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                for (int i = 0; i < spaces.length; i++) ...[
                  _SpaceRow(
                    name: spaces[i].name,
                    isActive: spaces[i].id == activeId,
                    onTap: () => mgr.switchSpace(spaces[i].id),
                    onRename: () => _renameSpace(
                        context, mgr, spaces[i].id, spaces[i].name),
                    onDelete: (spaces[i].id != 'default' &&
                            spaces[i].id != activeId)
                        ? () => _confirmDelete(context, mgr, spaces[i].id)
                        : null,
                  ),
                  if (i != spaces.length - 1) const SizedBox(height: 1),
                ],
                const SizedBox(height: 18),
                _AddRow(
                  label: s.newSpace,
                  onTap: () => _addSpace(context, mgr),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.name,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.circle_fill,
              size: 10,
              color: isActive ? AppColors.accent : CupertinoColors.transparent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRename,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 18,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 16,
                  color: AppColors.accent,
                ),
              )
            else if (onDelete != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    CupertinoIcons.delete,
                    size: 18,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.plus,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
