import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../localization/strings.dart';
import '../contacts/contact_controller.dart';
import '../folders/create_folder_list_sheet.dart';
import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../home_shell.dart';
import '../notes/note_controller.dart';
import '../search/search_pull_scope.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/smart_list_prefs.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/plus_button_inset_scope.dart';
import '../utils/plus_drag_controller.dart';
import '../utils/plus_drag_payload.dart';
import '../utils/reorder_drag.dart';
import '../utils/selection_checkbox.dart';
import '../utils/selection_controller.dart';
import '../utils/selection_menu.dart';
import '../utils/selection_toolbar.dart';
import '../utils/undo_controller.dart';
import 'all_tasks_view.dart';
import 'completed_view.dart';
import 'inbox_view.dart';
import 'task_controller.dart';
import 'task_field_prefs.dart';
import '../routines/routine_controller.dart';
import 'today_view.dart';
import 'tomorrow_view.dart';
import 'trash_view.dart';
import 'upcoming_view.dart';

class TasksView extends StatefulWidget {
  const TasksView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.contactController,
    required this.settingsController,
    required this.activeListId,
    required this.activeDueDate,
    required this.collapseSignal,
    this.activeFolderId,
    this.routineController,
    this.backupService,
    this.db,
    this.noteController,
    this.eventController,
  });

  final TaskController controller;
  final FolderController folderController;
  final ContactController contactController;
  final SettingsController settingsController;
  final RoutineController? routineController;
  final ValueNotifier<String?> activeListId;
  final ValueNotifier<DateTime?> activeDueDate;
  final ValueNotifier<int> collapseSignal;
  // Tracks the folder the user is currently viewing so the floating + button
  // can target that folder's default list. Set by [FolderView].
  final ValueNotifier<String?>? activeFolderId;
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
  final _selection = SelectionController();

  @override
  void initState() {
    super.initState();
    widget.collapseSignal.addListener(_collapseAll);
  }

  @override
  void dispose() {
    widget.collapseSignal.removeListener(_collapseAll);
    _selection.dispose();
    super.dispose();
  }

  // ── Selection batch actions ──────────────────────────────────────────────

  Future<void> _batchDeleteFolders() async {
    for (final id in _selection.selectedIds.toList()) {
      await widget.folderController.deleteFolderDeep(
          id, widget.controller.deleteTasksForList);
    }
    _selection.cancel();
  }

  Future<void> _batchDeleteLists() async {
    final ts = DateTime.now();
    for (final id in _selection.selectedIds.toList()) {
      await widget.controller.deleteTasksForList(id, ts);
      await widget.folderController.deleteList(id);
    }
    _selection.cancel();
  }

  Widget _wrapForSelection(String id, SelectionItemKind kind, String label,
      IconData icon, Widget child) {
    if (!_selection.active) return child;
    final selected = _selection.isSelected(id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selection.toggle(id, kind),
      child: Container(
        color: selected ? AppColors.accent.withOpacity(0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SelectionCheckbox(checked: selected),
            const SizedBox(width: 12),
            Icon(icon,
                size: 22,
                color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  List<SelectionAction> _buildBatchActions(S s) {
    final empty = _selection.isEmpty;
    if (_selection.kind == SelectionItemKind.folder) {
      return [
        SelectionAction(
          label: s.delete,
          icon: CupertinoIcons.trash,
          onTap: empty ? () {} : _batchDeleteFolders,
          isDestructive: true,
        ),
      ];
    }
    return [
      SelectionAction(
        label: s.delete,
        icon: CupertinoIcons.trash,
        onTap: empty ? () {} : _batchDeleteLists,
        isDestructive: true,
      ),
    ];
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
    // Mirror the folder ⋯ menu's "Default List" affordance — but only when
    // Inbox is hidden (otherwise new tasks have Inbox as their natural home)
    // and there's at least one list to pick.
    final inboxHidden = widget.settingsController.smartListPrefs.inbox ==
        SmartListVisibility.hidden;
    final hasLists = widget.folderController.lists.isNotEmpty;
    final showDefaultList = inboxHidden && hasLists;
    showDropdown(context, (dismiss) {
      return _TasksOptionsDropdown(
        onDismiss: dismiss,
        showSettings: settingsHidden,
        onSettings: settingsHidden
            ? () {
                dismiss();
                HomeShell.openGlobalSettings(context);
              }
            : null,
        onSelect: () {
          dismiss();
          _selection.start();
        },
        onAddList: () {
          dismiss();
          showCreateFolderListSheet(
            context,
            widget.folderController,
          );
        },
        onAddFolder: () {
          dismiss();
          showCreateFolderListSheet(
            context,
            widget.folderController,
            initialType: CreateSheetInitial.folder,
          );
        },
        onDefaultList: showDefaultList
            ? () {
                dismiss();
                _pickDefaultList(context);
              }
            : null,
      );
    });
  }

  Future<void> _pickDefaultList(BuildContext context) async {
    final s = S.of(context);
    final lists = widget.folderController.lists;
    if (lists.isEmpty) return;
    const noneSentinel = '__none__';
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.defaultList,
      current: widget.settingsController.defaultTaskListId ?? noneSentinel,
      // Anchor in the same top-right spot the parent ⋯ menu sat in.
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(value: noneSentinel, label: s.defaultListNone),
        for (final l in lists)
          SelectionMenuOption(value: l.id, label: l.name),
      ],
    );
    if (picked == null) return;
    await widget.settingsController.updateDefaultTaskListId(
      picked == noneSentinel ? null : picked,
    );
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

  /// Computes the task count to show next to a folder row, respecting the
  /// user's `folderCounterMode` preference. Returns null when no badge should
  /// render (mode = hidden or computed count is zero).
  int? _folderCount(String folderId) {
    final mode = widget.settingsController.taskFieldPrefs.folderCounterMode;
    final listIds = switch (mode) {
      FolderCounterMode.hidden => const <String>[],
      FolderCounterMode.directOnly =>
        widget.folderController.listIdsIn(folderId),
      FolderCounterMode.recursive =>
        widget.folderController.listIdsInRecursive(folderId),
    };
    if (mode == FolderCounterMode.hidden) return null;
    final count = widget.controller.uncompletedCountForLists(listIds);
    return count > 0 ? count : null;
  }

  int? _listCount(String listId) {
    if (!widget.settingsController.taskFieldPrefs.showListCount) return null;
    final c = widget.controller.uncompletedCountForList(listId);
    return c > 0 ? c : null;
  }

  Widget _buildFolderChildren(
      BuildContext context, String folderId, double indent) {
    final s = S.of(context);
    final subFolders = widget.folderController.foldersIn(folderId);
    final lists = widget.folderController.listsIn(folderId);

    return Column(
      children: [
        for (final f in subFolders) ...[
          Dismissible(
            key: ValueKey('exp_folder_${f.id}'),
            direction: DismissDirection.endToStart,
            background: _DeleteBackground(),
            confirmDismiss: (_) =>
                _confirmDelete(context, f.name, isFolder: true),
            onDismissed: (_) async {
              final undo = UndoScope.maybeOf(context);
              final ts = await widget.folderController.deleteFolderDeep(
                f.id,
                widget.controller.deleteTasksForList,
              );
              undo?.show(
                label: s.folderTrashedToast,
                onUndo: () async {
                  await widget.folderController.restoreAt(ts);
                  await widget.controller.restoreAt(ts);
                },
              );
            },
            child: _ListItem(
              iconAsset: 'assets/icons/folder.png',
              iconId: f.iconId,
              iconColor: f.iconColor,
              isFolder: true,
              label: f.name,
              indent: indent,
              count: _folderCount(f.id),
              // Folder rows can't accept a Plus drop directly — tasks live
              // in lists inside, not in folders. Auto-expand after 1.5s so
              // the user can keep dragging into a nested list.
              onHoverAutoExpand: () {
                if (!_expandedIds.contains(f.id)) _toggle(f.id);
              },
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => FolderView(
                    folder: f,
                    folderController: widget.folderController,
                    taskController: widget.controller,
                    contactController: widget.contactController,
                    activeListId: widget.activeListId,
                    activeFolderId: widget.activeFolderId,
                    settingsController: widget.settingsController,
                  ),
                ),
              ),
              onExpand: () => _toggle(f.id),
              isExpanded: _expandedIds.contains(f.id),
            ),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final l in lists) ...[
          Dismissible(
            key: ValueKey('exp_list_${l.id}'),
            direction: DismissDirection.endToStart,
            background: _DeleteBackground(),
            confirmDismiss: (_) =>
                _confirmDelete(context, l.name, isFolder: false),
            onDismissed: (_) async {
              final undo = UndoScope.maybeOf(context);
              final ts = DateTime.now();
              final savedFolderId = l.folderId;
              await widget.controller.deleteTasksForList(l.id, ts);
              await widget.folderController.deleteList(l.id);
              undo?.show(
                label: s.listTrashedToast,
                onUndo: () async {
                  await widget.folderController
                      .restoreList(l.id, savedFolderId);
                  await widget.controller.restoreAt(ts);
                },
              );
            },
            child: _ListItem(
              iconAsset: 'assets/icons/list.png',
              iconId: l.iconId,
              iconColor: l.iconColor,
              isFolder: false,
              label: l.name,
              indent: indent,
              count: _listCount(l.id),
              onAcceptPlus: () =>
                  PlusDragScope.of(context)?.onDropOnList?.call(l.id),
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => ListTaskView(
                    list: l,
                    taskController: widget.controller,
                    folderController: widget.folderController,
                    contactController: widget.contactController,
                    activeListId: widget.activeListId,
                  ),
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
    final canSearch = widget.db != null &&
        widget.noteController != null &&
        widget.eventController != null;
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final selecting = _selection.active;
        final rootFolders = widget.folderController.foldersIn(null);
        final rootLists = widget.folderController.listsIn(null);
        final hasMixed = rootFolders.isNotEmpty && rootLists.isNotEmpty;
        final selectKind = _selection.kind;
        Iterable<String>? selectAllIds;
        if (selectKind == SelectionItemKind.folder) {
          selectAllIds = rootFolders.map((f) => f.id);
        } else if (selectKind == SelectionItemKind.list) {
          selectAllIds = rootLists.map((l) => l.id);
        } else if (!hasMixed) {
          if (rootLists.isNotEmpty) {
            selectAllIds = rootLists.map((l) => l.id);
          } else if (rootFolders.isNotEmpty) {
            selectAllIds = rootFolders.map((f) => f.id);
          }
        }
        final allIds = selectAllIds?.toSet() ?? <String>{};
        final allSelected = allIds.isNotEmpty &&
            _selection.selectedIds.containsAll(allIds) &&
            _selection.count >= allIds.length;
        return PlusButtonLift(
          lift: selecting ? kSelectionToolbarLift : 0,
          child: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
        border: null,
        leading: selecting
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selection.cancel,
                child: Text(s.cancel),
              )
            : null,
        automaticallyImplyLeading: !selecting,
        middle: Text(selecting
            ? (_selection.count == 0
                ? s.selectItems
                : s.selectedCount(_selection.count))
            : s.tabTasks),
        trailing: selecting
            ? (selectAllIds != null
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (allSelected) {
                        _selection.replaceAll(const [],
                            selectKind ?? SelectionItemKind.list);
                      } else {
                        _selection.replaceAll(
                            allIds,
                            selectKind ??
                                (rootLists.isNotEmpty
                                    ? SelectionItemKind.list
                                    : SelectionItemKind.folder));
                      }
                    },
                    child: Text(
                        allSelected ? s.deselectAll : s.selectAll),
                  )
                : null)
            : Semantics(
                label: s.settings,
                button: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showDropdown(context),
                  child: const Icon(CupertinoIcons.ellipsis, size: 26),
                ),
              ),
      ),
      child: SafeArea(
        bottom: !selecting,
        child: Column(
          children: [
            Expanded(
              child: Stack(
          children: [
            _maybeWrapWithSearchPull(
              canSearch: canSearch,
              child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.controller,
                widget.folderController,
                widget.settingsController,
              ]),
              builder: (context, _) {
                final rootFolders =
                    widget.folderController.foldersIn(null);
                final rootLists = widget.folderController.listsIn(null);
                var todayCount = widget.controller.todayUncompletedCount;
                // Optionally fold today's routines / events into the Today
                // count badge (mirrors what the Today view surfaces).
                final sc = widget.settingsController;
                if (sc.countRoutinesInToday &&
                    widget.routineController != null) {
                  todayCount +=
                      widget.routineController!.todayUncompletedCount;
                }
                if (sc.showEventsInToday &&
                    sc.countEventsInToday &&
                    widget.eventController != null) {
                  final now = DateTime.now();
                  // Exclude events that have already finished — they show in
                  // the Today section greyed out but don't inflate the badge.
                  todayCount += widget.eventController!
                      .eventsForDate(DateTime(now.year, now.month, now.day))
                      .where((e) => !e.isPastAt(now))
                      .length;
                }
                final tomorrowCount =
                    widget.controller.tomorrowUncompletedCount;
                final upcomingCount =
                    widget.controller.upcomingUncompletedCount;
                final allTasksCount =
                    widget.controller.allTasksUncompletedCount;
                final completedCount =
                    widget.controller.completedTasksCount;
                final hasTrashContent =
                    widget.controller.trashedTasks.isNotEmpty ||
                        widget.folderController.trashedFolders.isNotEmpty ||
                        widget.folderController.trashedLists.isNotEmpty;

                final prefs =
                    widget.settingsController.smartListPrefs;
                final inboxCount =
                    widget.controller.inboxUncompletedCount;
                final showInbox = _isVisible(prefs.inbox, inboxCount > 0);
                final showToday =
                    _isVisible(prefs.today, todayCount > 0);
                final showTomorrow =
                    _isVisible(prefs.tomorrow, tomorrowCount > 0);
                final showUpcoming =
                    _isVisible(prefs.upcoming, upcomingCount > 0);
                final showAllTasks =
                    _isVisible(prefs.allTasks, allTasksCount > 0);
                final showCompleted =
                    _isVisible(prefs.completed, completedCount > 0);
                final showTrash =
                    _isVisible(prefs.trash, hasTrashContent);
                final showBottomSection = showCompleted || showTrash;
                // Drop the divider between smart lists and folders/lists when
                // no smart-list row is rendered — otherwise the divider sits
                // alone at the top of the screen for no reason.
                final showTopDivider = showInbox ||
                    showToday ||
                    showTomorrow ||
                    showUpcoming ||
                    showAllTasks;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          if (showInbox)
                            _ListItem(
                              iconAsset: 'assets/icons/inbox.png',
                              label: s.inbox,
                              count: widget
                                  .controller.inboxUncompletedCount,
                              onAcceptPlus: () => PlusDragScope.of(context)
                                  ?.onDropOnSmartList
                                  ?.call(PlusDropSmartList.inbox),
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
                              onAcceptPlus: () => PlusDragScope.of(context)
                                  ?.onDropOnSmartList
                                  ?.call(PlusDropSmartList.today),
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => TodayView(
                                    controller: widget.controller,
                                    folderController:
                                        widget.folderController,
                                    activeDueDate: widget.activeDueDate,
                                    routineController:
                                        widget.routineController,
                                    eventController:
                                        widget.eventController,
                                    settingsController:
                                        widget.settingsController,
                                  ),
                                ),
                              ),
                            ),
                          if (showTomorrow)
                            _ListItem(
                              iconWidget: Icon(
                                CupertinoIcons.sun_max,
                                size: 22,
                                color: CupertinoColors.systemOrange
                                    .resolveFrom(context),
                              ),
                              label: s.tomorrow,
                              count: tomorrowCount > 0
                                  ? tomorrowCount
                                  : null,
                              onAcceptPlus: () => PlusDragScope.of(context)
                                  ?.onDropOnSmartList
                                  ?.call(PlusDropSmartList.tomorrow),
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => TomorrowView(
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
                              onAcceptPlus: () => PlusDragScope.of(context)
                                  ?.onDropOnSmartList
                                  ?.call(PlusDropSmartList.upcoming),
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
                          if (showAllTasks)
                            _ListItem(
                              iconWidget: Icon(
                                CupertinoIcons.tray_full,
                                size: 22,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                              label: s.allTasks,
                              count: allTasksCount > 0
                                  ? allTasksCount
                                  : null,
                              onAcceptPlus: () => PlusDragScope.of(context)
                                  ?.onDropOnSmartList
                                  ?.call(PlusDropSmartList.allTasks),
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => AllTasksView(
                                    controller: widget.controller,
                                    folderController:
                                        widget.folderController,
                                  ),
                                ),
                              ),
                            ),
                          // Separator between smart lists and user folders/lists.
                          // Hide when no smart list row is rendered above — an
                          // empty top divider was the previous (confusing)
                          // behaviour.
                          if (showTopDivider)
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

                    // Reorderable folders — long-press to drag, drop on
                    // another folder to insert before, drop on the trailing
                    // slot to push to the end.
                    if (rootFolders.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final f = rootFolders[index];
                            return Column(
                              key: ValueKey('folder_${f.id}'),
                              children: [
                                ReorderableDropZone(
                                  kind: ReorderKind.folder,
                                  beforeId: f.id,
                                  onReorder: (movedId, beforeId) =>
                                      widget.folderController
                                          .reorderFolderBefore(
                                    movedId: movedId,
                                    beforeId: beforeId,
                                    parentFolderId: null,
                                  ),
                                  child: ReorderableRow(
                                    id: f.id,
                                    kind: ReorderKind.folder,
                                    label: f.name,
                                    child: Dismissible(
                                      key: ValueKey(f.id),
                                      direction: DismissDirection.endToStart,
                                      background: _DeleteBackground(),
                                      confirmDismiss: (_) => _confirmDelete(
                                          context, f.name,
                                          isFolder: true),
                                      onDismissed: (_) async {
                                        final undo =
                                            UndoScope.maybeOf(context);
                                        final ts = await widget
                                            .folderController
                                            .deleteFolderDeep(
                                          f.id,
                                          widget.controller
                                              .deleteTasksForList,
                                        );
                                        undo?.show(
                                          label: s.folderTrashedToast,
                                          onUndo: () async {
                                            await widget.folderController
                                                .restoreAt(ts);
                                            await widget.controller
                                                .restoreAt(ts);
                                          },
                                        );
                                      },
                                      child: _wrapForSelection(
                                          f.id,
                                          SelectionItemKind.folder,
                                          f.name,
                                          CupertinoIcons.folder,
                                          _ListItem(
                                        iconAsset: 'assets/icons/folder.png',
                                        iconId: f.iconId,
                                        iconColor: f.iconColor,
                                        isFolder: true,
                                        label: f.name,
                                        count: _folderCount(f.id),
                                        onHoverAutoExpand: () {
                                          if (!_expandedIds
                                              .contains(f.id)) {
                                            _toggle(f.id);
                                          }
                                        },
                                        onTap: () => Navigator.of(context)
                                            .push(
                                          FastRoute<void>(
                                            builder: (_) => FolderView(
                                              folder: f,
                                              folderController:
                                                  widget.folderController,
                                              taskController:
                                                  widget.controller,
                                              contactController:
                                                  widget.contactController,
                                              activeListId:
                                                  widget.activeListId,
                                              activeFolderId:
                                                  widget.activeFolderId,
                                              settingsController:
                                                  widget.settingsController,
                                            ),
                                          ),
                                        ),
                                        onExpand: () => _toggle(f.id),
                                        isExpanded:
                                            _expandedIds.contains(f.id),
                                      )),
                                    ),
                                  ),
                                ),
                                if (_expandedIds.contains(f.id))
                                  _buildFolderChildren(context, f.id, 24),
                              ],
                            );
                          },
                          childCount: rootFolders.length,
                        ),
                      ),
                    if (rootFolders.isNotEmpty)
                      SliverToBoxAdapter(
                        child: ReorderableTrailingSlot(
                          kind: ReorderKind.folder,
                          onReorder: (movedId) => widget.folderController
                              .reorderFolderBefore(
                            movedId: movedId,
                            beforeId: null,
                            parentFolderId: null,
                          ),
                        ),
                      ),

                    // Reorderable lists
                    if (rootLists.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final l = rootLists[index];
                            return ReorderableDropZone(
                              key: ValueKey('list_${l.id}'),
                              kind: ReorderKind.list,
                              beforeId: l.id,
                              onReorder: (movedId, beforeId) => widget
                                  .folderController
                                  .reorderListBefore(
                                movedId: movedId,
                                beforeId: beforeId,
                                folderId: null,
                              ),
                              child: ReorderableRow(
                                id: l.id,
                                kind: ReorderKind.list,
                                label: l.name,
                                child: Dismissible(
                                  key: ValueKey(l.id),
                                  direction: DismissDirection.endToStart,
                                  background: _DeleteBackground(),
                                  confirmDismiss: (_) => _confirmDelete(
                                      context, l.name,
                                      isFolder: false),
                                  onDismissed: (_) async {
                                    final undo =
                                        UndoScope.maybeOf(context);
                                    final ts = DateTime.now();
                                    final savedFolderId = l.folderId;
                                    await widget.controller
                                        .deleteTasksForList(l.id, ts);
                                    await widget.folderController
                                        .deleteList(l.id);
                                    undo?.show(
                                      label: s.listTrashedToast,
                                      onUndo: () async {
                                        await widget.folderController
                                            .restoreList(
                                                l.id, savedFolderId);
                                        await widget.controller
                                            .restoreAt(ts);
                                      },
                                    );
                                  },
                                  child: _wrapForSelection(
                                      l.id,
                                      SelectionItemKind.list,
                                      l.name,
                                      CupertinoIcons.list_bullet,
                                      _ListItem(
                                    iconAsset: 'assets/icons/list.png',
                                    iconId: l.iconId,
                                    iconColor: l.iconColor,
                                    isFolder: false,
                                    label: l.name,
                                    count: _listCount(l.id),
                                    onAcceptPlus: () =>
                                        PlusDragScope.of(context)
                                            ?.onDropOnList
                                            ?.call(l.id),
                                    onTap: () => Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => ListTaskView(
                                          list: l,
                                          taskController: widget.controller,
                                          folderController:
                                              widget.folderController,
                                          contactController:
                                              widget.contactController,
                                          activeListId: widget.activeListId,
                                        ),
                                      ),
                                    ),
                                  )),
                                ),
                              ),
                            );
                          },
                          childCount: rootLists.length,
                        ),
                      ),
                    if (rootLists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: ReorderableTrailingSlot(
                          kind: ReorderKind.list,
                          onReorder: (movedId) => widget.folderController
                              .reorderListBefore(
                            movedId: movedId,
                            beforeId: null,
                            folderId: null,
                          ),
                        ),
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
            ),
            if (widget.settingsController.smartListPrefs.showAddFolderButton &&
                !selecting)
              Positioned(
                left: 20,
                bottom: 16,
                child: _CircleAddButton(
                  onPressed: () => showCreateFolderListSheet(
                      context, widget.folderController),
                  onAcceptPlus: () => PlusDragScope.of(context)
                      ?.onDropOnAddFolderButton
                      ?.call(),
                ),
              ),
          ],
        ),
            ),
            if (selecting)
              SelectionToolbar(
                bottomInset: MediaQuery.paddingOf(context).bottom,
                actions: _buildBatchActions(s),
              ),
          ],
        ),
      ),
        ),
        );
      },
    );
  }

  Widget _maybeWrapWithSearchPull({
    required bool canSearch,
    required Widget child,
  }) {
    if (!canSearch) return child;
    return SearchPullScope(
      db: widget.db!,
      taskController: widget.controller,
      folderController: widget.folderController,
      noteController: widget.noteController!,
      eventController: widget.eventController!,
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
    this.iconColor,
    this.isFolder = false,
    this.count,
    this.onExpand,
    this.isExpanded = false,
    this.indent = 0,
    this.onAcceptPlus,
    this.onHoverAutoExpand,
  });

  final String? iconAsset;
  final Widget? iconWidget;
  final String? iconId;
  final int? iconColor;
  final bool isFolder;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;
  final VoidCallback? onAcceptPlus;
  // Folders only — invoked when the Plus button has hovered over this row
  // for 1.5s so the user can drill into a nested list. When set, the row
  // shows a gray highlight (not the accent drop target) and a 1.5s ring
  // progress indicator.
  final VoidCallback? onHoverAutoExpand;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (iconWidget != null) {
      icon = iconWidget!;
    } else if (iconId != null) {
      icon = buildFolderItemIcon(iconId,
          isFolder: isFolder, iconColor: iconColor);
    } else {
      icon = Image.asset(iconAsset!, width: 22, height: 22);
    }

    final row = IntrinsicHeight(
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

    if (onHoverAutoExpand != null) {
      return _FolderHoverDropTarget(
        onAutoExpand: onHoverAutoExpand!,
        child: row,
      );
    }
    if (onAcceptPlus == null) return row;
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAcceptPlus!(),
      builder: (context, candidates, _) {
        return Container(
          decoration: candidates.isEmpty
              ? null
              : BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: row,
        );
      },
    );
  }
}

/// Drop target wrapper for **folder** rows. Plus-button drops on folders
/// don't create anything — the user must drill into one of the folder's
/// lists — so this widget instead waits 1.5s while the button hovers,
/// then auto-expands the folder. While hovering it tints the row light
/// gray (not accent-orange) and draws a thin progress bar across the
/// bottom edge that fills as the timer runs.
class _FolderHoverDropTarget extends StatefulWidget {
  const _FolderHoverDropTarget({
    required this.onAutoExpand,
    required this.child,
  });

  final VoidCallback onAutoExpand;
  final Widget child;

  static const Duration hoverDuration = Duration(milliseconds: 1500);

  @override
  State<_FolderHoverDropTarget> createState() => _FolderHoverDropTargetState();
}

class _FolderHoverDropTargetState extends State<_FolderHoverDropTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _FolderHoverDropTarget.hoverDuration,
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAutoExpand();
        // Reset so the user can re-trigger if they hover again without
        // dropping (e.g. the folder is still empty after expanding).
        _ctrl.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) {
        _ctrl.forward(from: 0);
        return true;
      },
      onLeave: (_) {
        _ctrl.stop();
        _ctrl.value = 0;
      },
      // No onAcceptWithDetails — dropping on a folder isn't a creation
      // action; the user is expected to drop on one of its lists.
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Stack(
          children: [
            Container(
              decoration: hovering
                  ? BoxDecoration(
                      color: CupertinoColors.systemGrey4
                          .resolveFrom(context)
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: widget.child,
            ),
            if (hovering)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => SizedBox(
                    height: 2,
                    child: Stack(
                      children: [
                        Container(
                          color: CupertinoColors.separator
                              .resolveFrom(context),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _ctrl.value,
                          child: Container(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TasksOptionsDropdown extends StatelessWidget {
  const _TasksOptionsDropdown({
    required this.onDismiss,
    required this.onAddList,
    required this.onAddFolder,
    required this.onSelect,
    this.showSettings = false,
    this.onSettings,
    this.onDefaultList,
  });

  final VoidCallback onDismiss;
  final VoidCallback onAddList;
  final VoidCallback onAddFolder;
  final VoidCallback onSelect;
  final bool showSettings;
  final VoidCallback? onSettings;
  // When non-null, render a "Default list" row that opens a list picker —
  // shown only when Inbox is hidden so new tasks need a destination.
  final VoidCallback? onDefaultList;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final s = S.of(context);
    final separator = Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
    final items = <Widget>[
      DropdownRow(
        label: s.select,
        icon: CupertinoIcons.checkmark_circle,
        onTap: onSelect,
      ),
      separator,
      DropdownRow(
        label: s.addList,
        icon: CupertinoIcons.add_circled,
        onTap: onAddList,
      ),
      separator,
      DropdownRow(
        label: s.addFolder,
        icon: CupertinoIcons.folder_badge_plus,
        onTap: onAddFolder,
      ),
      if (onDefaultList != null) ...[
        separator,
        DropdownRow(
          label: s.defaultList,
          icon: CupertinoIcons.list_bullet_below_rectangle,
          onTap: onDefaultList!,
        ),
      ],
    ];
    if (showSettings) {
      items.add(separator);
      items.add(DropdownRow(
        label: s.settings,
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
        Positioned(
          top: topOffset,
          right: 8,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
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
  const _CircleAddButton({required this.onPressed, this.onAcceptPlus});
  final VoidCallback onPressed;
  // When set, the button doubles as a drop target for the global Plus
  // drag — releasing the Plus button here opens the create-list/folder
  // sheet instead of the standard task creation flow.
  final VoidCallback? onAcceptPlus;

  Widget _button(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    if (onAcceptPlus == null) return _button(context);
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAcceptPlus!(),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: hovering
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: _button(context),
        );
      },
    );
  }
}
