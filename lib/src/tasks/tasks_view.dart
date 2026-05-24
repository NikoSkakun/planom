import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../localization/strings.dart';
import '../folders/create_folder_list_sheet.dart';
import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../notes/note_controller.dart';
import '../search/search_view.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_view.dart';
import '../settings/smart_list_prefs.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import 'completed_view.dart';
import 'inbox_view.dart';
import 'task_controller.dart';
import 'today_view.dart';
import 'trash_view.dart';
import 'upcoming_view.dart';

class TasksView extends StatefulWidget {
  const TasksView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.settingsController,
    required this.activeListId,
    required this.activeDueDate,
    required this.collapseSignal,
    this.backupService,
    this.db,
    this.noteController,
    this.eventController,
  });

  final TaskController controller;
  final FolderController folderController;
  final SettingsController settingsController;
  final ValueNotifier<String?> activeListId;
  final ValueNotifier<DateTime?> activeDueDate;
  final ValueNotifier<int> collapseSignal;
  final BackupService? backupService;
  // Optional: when provided, the nav bar shows a global-search button that
  // queries all three (tasks, notes, events) via FTS5.
  final DatabaseService? db;
  final NoteController? noteController;
  final EventController? eventController;

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> with DropdownOverlayMixin {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    widget.collapseSignal.addListener(_collapseAll);
  }

  @override
  void dispose() {
    widget.collapseSignal.removeListener(_collapseAll);
    super.dispose();
  }

  void _collapseAll() {
    if (_expandedIds.isNotEmpty) setState(() => _expandedIds.clear());
  }

  void _toggle(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _showDropdown(BuildContext context) {
    final settingsHidden = !widget.settingsController.isTabVisible(4);
    showDropdown(context, (dismiss) {
      return _TasksOptionsDropdown(
        onDismiss: dismiss,
        showSettings: settingsHidden,
        onSettings: settingsHidden
            ? () {
                dismiss();
                Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => SettingsView(
                      controller: widget.settingsController,
                      backupService: widget.backupService,
                    ),
                  ),
                );
              }
            : null,
      );
    });
  }

  Future<bool> _confirmDelete(BuildContext context, String name,
          {required bool isFolder}) {
    final s = S.of(context);
    return confirmMoveToTrash(
      context,
      name: name,
      isFolder: isFolder,
      body: isFolder ? s.moveToTrashFolderBody : s.moveToTrashListBody,
    );
  }

  Widget _buildFolderChildren(
      BuildContext context, String folderId, double indent) {
    final subFolders = widget.folderController.foldersIn(folderId);
    final lists = widget.folderController.listsIn(folderId);

    return Column(
      children: [
        for (final f in subFolders) ...[
          _ListItem(
            iconAsset: 'assets/icons/folder.png',
            iconId: f.iconId,
            isFolder: true,
            label: f.name,
            indent: indent,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => FolderView(
                  folder: f,
                  folderController: widget.folderController,
                  taskController: widget.controller,
                  activeListId: widget.activeListId,
                ),
              ),
            ),
            onExpand: () => _toggle(f.id),
            isExpanded: _expandedIds.contains(f.id),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final l in lists) ...[
          _ListItem(
            iconAsset: 'assets/icons/list.png',
            iconId: l.iconId,
            isFolder: false,
            label: l.name,
            indent: indent,
            count: widget.controller.uncompletedCountForList(l.id) > 0
                ? widget.controller.uncompletedCountForList(l.id)
                : null,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => ListTaskView(
                  list: l,
                  taskController: widget.controller,
                  folderController: widget.folderController,
                  activeListId: widget.activeListId,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static bool _isVisible(SmartListVisibility vis, bool hasContent) {
    switch (vis) {
      case SmartListVisibility.show:
        return true;
      case SmartListVisibility.showIfNotEmpty:
        return hasContent;
      case SmartListVisibility.hidden:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabTasks),
        leading: widget.db != null &&
                widget.noteController != null &&
                widget.eventController != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => SearchView(
                      db: widget.db!,
                      taskController: widget.controller,
                      folderController: widget.folderController,
                      noteController: widget.noteController!,
                      eventController: widget.eventController!,
                    ),
                  ),
                ),
                child: const Icon(CupertinoIcons.search, size: 22),
              )
            : null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                widget.controller,
                widget.folderController,
                widget.settingsController,
              ]),
              builder: (context, _) {
                final rootFolders =
                    widget.folderController.foldersIn(null);
                final rootLists = widget.folderController.listsIn(null);
                final todayCount = widget.controller.todayUncompletedCount;
                final upcomingCount =
                    widget.controller.upcomingUncompletedCount;
                final completedCount =
                    widget.controller.completedTasksCount;
                final hasTrashContent =
                    widget.controller.trashedTasks.isNotEmpty ||
                        widget.folderController.trashedFolders.isNotEmpty ||
                        widget.folderController.trashedLists.isNotEmpty;

                final prefs =
                    widget.settingsController.smartListPrefs;
                final showToday =
                    _isVisible(prefs.today, todayCount > 0);
                final showUpcoming =
                    _isVisible(prefs.upcoming, upcomingCount > 0);
                final showCompleted =
                    _isVisible(prefs.completed, completedCount > 0);
                final showTrash =
                    _isVisible(prefs.trash, hasTrashContent);
                final showBottomSection = showCompleted || showTrash;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _ListItem(
                            iconAsset: 'assets/icons/inbox.png',
                            label: s.inbox,
                            count: widget
                                .controller.inboxUncompletedCount,
                            onTap: () => Navigator.of(context).push(
                              FastRoute<void>(
                                builder: (_) => InboxView(
                                  controller: widget.controller,
                                  folderController:
                                      widget.folderController,
                                ),
                              ),
                            ),
                          ),
                          if (showToday)
                            _ListItem(
                              iconAsset: 'assets/icons/today.png',
                              label: s.today,
                              count:
                                  todayCount > 0 ? todayCount : null,
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => TodayView(
                                    controller: widget.controller,
                                    folderController:
                                        widget.folderController,
                                    activeDueDate: widget.activeDueDate,
                                  ),
                                ),
                              ),
                            ),
                          if (showUpcoming)
                            _ListItem(
                              iconAsset: 'assets/icons/upcoming.png',
                              label: s.upcoming,
                              count: upcomingCount > 0
                                  ? upcomingCount
                                  : null,
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => UpcomingView(
                                    controller: widget.controller,
                                    folderController:
                                        widget.folderController,
                                  ),
                                ),
                              ),
                            ),
                          // Separator between smart lists and user folders/lists
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Container(
                              height: 0.5,
                              color: CupertinoColors.separator
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Reorderable folders
                    if (rootFolders.isNotEmpty)
                      SliverReorderableList(
                        itemCount: rootFolders.length,
                        onReorder: (oldIndex, newIndex) =>
                            widget.folderController.reorderFolders(
                                null, oldIndex, newIndex),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final f = rootFolders[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('folder_${f.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(f.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) => _confirmDelete(
                                  context, f.name,
                                  isFolder: true),
                              onDismissed: (_) =>
                                  widget.folderController.deleteFolderDeep(
                                f.id,
                                widget.controller.deleteTasksForList,
                              ),
                              child: Column(
                                children: [
                                  _ListItem(
                                    iconAsset: 'assets/icons/folder.png',
                                    iconId: f.iconId,
                                    isFolder: true,
                                    label: f.name,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => FolderView(
                                          folder: f,
                                          folderController:
                                              widget.folderController,
                                          taskController: widget.controller,
                                          activeListId: widget.activeListId,
                                        ),
                                      ),
                                    ),
                                    onExpand: () => _toggle(f.id),
                                    isExpanded:
                                        _expandedIds.contains(f.id),
                                  ),
                                  if (_expandedIds.contains(f.id))
                                    _buildFolderChildren(
                                        context, f.id, 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Reorderable lists
                    if (rootLists.isNotEmpty)
                      SliverReorderableList(
                        itemCount: rootLists.length,
                        onReorder: (oldIndex, newIndex) =>
                            widget.folderController.reorderLists(
                                null, oldIndex, newIndex),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final l = rootLists[index];
                          final count = widget.controller
                              .uncompletedCountForList(l.id);
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('list_${l.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) => _confirmDelete(
                                  context, l.name,
                                  isFolder: false),
                              onDismissed: (_) async {
                                await widget.controller
                                    .deleteTasksForList(l.id);
                                await widget.folderController
                                    .deleteList(l.id);
                              },
                              child: _ListItem(
                                iconAsset: 'assets/icons/list.png',
                                iconId: l.iconId,
                                isFolder: false,
                                label: l.name,
                                count: count > 0 ? count : null,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: widget.controller,
                                      folderController:
                                          widget.folderController,
                                      activeListId: widget.activeListId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // Bottom section: Completed + Trash smart lists
                    if (showBottomSection)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Container(
                                height: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                            ),
                            if (showCompleted)
                              _ListItem(
                                iconWidget: Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  size: 22,
                                  color: AppColors.systemGreen,
                                ),
                                label: s.completed,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => CompletedView(
                                      controller: widget.controller,
                                      folderController:
                                          widget.folderController,
                                    ),
                                  ),
                                ),
                              ),
                            if (showTrash)
                              _ListItem(
                                iconWidget: Icon(
                                  CupertinoIcons.trash,
                                  size: 22,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                                label: s.trash,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => TrashView(
                                      taskController: widget.controller,
                                      folderController:
                                          widget.folderController,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              child: _CircleAddButton(
                onPressed: () => showCreateFolderListSheet(
                    context, widget.folderController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: CupertinoColors.destructiveRed,
      child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.iconWidget,
    this.iconId,
    this.isFolder = false,
    this.count,
    this.onExpand,
    this.isExpanded = false,
    this.indent = 0,
  });

  final String? iconAsset;
  final Widget? iconWidget;
  final String? iconId;
  final bool isFolder;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (iconWidget != null) {
      icon = iconWidget!;
    } else if (iconId != null) {
      icon = buildFolderItemIcon(iconId, isFolder: isFolder);
    } else {
      icon = Image.asset(iconAsset!, width: 22, height: 22);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MergeSemantics(
              child: Semantics(
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        16 + indent, 9, onExpand != null ? 4 : 16, 9),
                    child: Row(
                      children: [
                        SizedBox(width: 22, height: 22, child: icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isFolder
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (count != null && count! > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onExpand != null)
            GestureDetector(
              onTap: onExpand,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 48,
                child: Center(
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TasksOptionsDropdown extends StatelessWidget {
  const _TasksOptionsDropdown({
    required this.onDismiss,
    this.showSettings = false,
    this.onSettings,
  });

  final VoidCallback onDismiss;
  final bool showSettings;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final items = <Widget>[];
    if (showSettings) {
      items.add(DropdownRow(
        label: S.of(context).settings,
        icon: CupertinoIcons.gear_alt,
        onTap: onSettings ?? () {},
      ));
    }
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        if (items.isNotEmpty)
          Positioned(
            top: topOffset,
            right: 8,
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color:
                    CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items,
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleAddButton extends StatelessWidget {
  const _CircleAddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground
              .resolveFrom(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.folder_badge_plus,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
