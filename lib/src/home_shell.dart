import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'localization/strings.dart';
import 'calendar/event_controller.dart';
import 'calendar/event_creation_sheet.dart';
import 'contacts/contact_controller.dart';
import 'contacts/contact_creation_sheet.dart';
import 'finance/finance_controller.dart';
import 'finance/finance_view.dart';
import 'finance/transaction_sheet.dart';
import 'goals/goal_controller.dart';
import 'goals/goal_editor_view.dart';
import 'goals/goals_view.dart';
import 'folders/create_folder_list_sheet.dart';
import 'folders/folder_controller.dart';
import 'integrations/apple/device_calendar_controller.dart';
import 'integrations/google/google_calendar_controller.dart';
import 'models/list_type.dart';
import 'notes/create_note_folder_sheet.dart';
import 'notes/note_controller.dart';
import 'notes/notes_view.dart';
import 'spaces/space.dart';
import 'spaces/space_manager.dart';
import 'spaces/space_switch_transition.dart';
import 'routines/routine_controller.dart';
import 'routines/routine_creation_view.dart';
import 'routines/routines_view.dart';
import 'security/security_service.dart';
import 'settings/backup_service.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';
import 'settings/smart_list_prefs.dart';
import 'settings/tab_bar_config.dart';
import 'utils/shortcut_router.dart';
import 'tasks/overdue_tasks_view.dart';
import 'tasks/task_controller.dart';
import 'tasks/task_creation_sheet.dart';
import 'tasks/tasks_view.dart';
import 'theme/app_theme.dart';
import 'utils/day_boundary.dart';
import 'utils/fast_route.dart';
import 'utils/platform_capabilities.dart';
import 'utils/plus_button_inset_scope.dart';
import 'utils/plus_drag_controller.dart';
import 'utils/plus_drag_payload.dart';
import 'utils/selection_menu.dart';
import 'utils/task_drag_scope.dart';
import 'notes/note_detail_view.dart';
import 'models/note.dart';
import 'utils/undo_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settingsController,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.eventController,
    required this.contactController,
    required this.financeController,
    required this.goalController,
    required this.backupService,
    this.securityService,
    required this.googleCalendarController,
    required this.deviceCalendarController,
  });

  static const routeName = '/';

  /// Opens Settings as a global overlay above the tab bar. Used from any
  /// tab's ⋯ menu when the Settings tab is hidden. While the overlay is
  /// visible, the tab bar shows every tab as inactive.
  static void openGlobalSettings(BuildContext context) {
    context
        .findRootAncestorStateOfType<_HomeShellState>()
        ?._openGlobalSettings();
  }

  /// Enters Split Screen mode pairing the currently-active tab (the host) with
  /// [withTab]. Invoked from the Tasks / Calendar ⋯ menus. The host renders on
  /// top, [withTab] on the bottom; the arrangement can be flipped afterwards by
  /// dragging a window header.
  static void enterSplitScreen(BuildContext context, {required int withTab}) {
    context
        .findRootAncestorStateOfType<_HomeShellState>()
        ?._enterSplitFromMenu(withTab);
  }

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final ContactController contactController;
  final FinanceController financeController;
  final GoalController goalController;
  final BackupService backupService;
  final SecurityService? securityService;
  final GoogleCalendarController googleCalendarController;
  final DeviceCalendarController deviceCalendarController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Tab to open in the next shell, set just before a Space switch so swiping
/// between Spaces keeps the user on the tab they were reading. It survives
/// because `main.dart` re-keys `MyApp` per Space — the old shell's state is
/// thrown away, so the hand-off can't live on the State object. Consumed
/// exactly once by the next [_HomeShellState.initState].
int? _tabAcrossSpaceSwitch;

class _HomeShellState extends State<HomeShell> {
  // Logical indices:
  // 0=Tasks 1=Notes 2=Calendar 3=Routines 4=Settings 5=Finance 6=Goals
  final _navigatorKeys = List.generate(7, (_) => GlobalKey<NavigatorState>());
  late final List<_DepthObserver> _depthObservers;
  final _activeListId = ValueNotifier<String?>(null);
  final _activeFolderId = ValueNotifier<String?>(null);
  final _activeDueDate = ValueNotifier<DateTime?>(null);
  // The calendar's currently-selected day. Kept separate from [_activeDueDate]
  // (which is owned by the Tasks tab's Today/Tomorrow views) so a day selected
  // in the Calendar tab never leaks into the Tasks tab's + creation sheet —
  // every tab is kept alive simultaneously, so a shared notifier would bleed
  // the calendar selection across tabs.
  final _activeCalendarDate = ValueNotifier<DateTime?>(null);
  final _tasksCollapseSignal = ValueNotifier<int>(0);
  final _notesCollapseSignal = ValueNotifier<int>(0);
  final _calendarResetSignal = ValueNotifier<int>(0);
  final _routinesResetSignal = ValueNotifier<int>(0);
  final _financeResetSignal = ValueNotifier<int>(0);
  // Month currently shown on the Finance tab (null = the present month), so a
  // + tap creates the entry inside the month the user is looking at.
  final _activeFinanceMonth = ValueNotifier<DateTime?>(null);
  // Account the Finance tab is filtered to (null = all), so a + tap creates
  // the entry on the account the user is looking at.
  final _activeFinanceAccount = ValueNotifier<String?>(null);
  final _showPlusButton = ValueNotifier<bool>(true);
  final _plusButtonInset = ValueNotifier<double>(0);
  final _undoController = UndoController();
  final _plusDragController = PlusDragController();
  // True while the user is viewing Settings via the global overlay (i.e. the
  // Settings tab is hidden but they opened Settings from another tab's ⋯
  // menu, or hid the Settings tab while in it). The overlay is rendered
  // inside the shell's Stack — above the tab content but leaving the tab bar
  // (or the wide-layout sidebar) visible — and the bar repaints all tabs as
  // inactive while this is true. It reuses the Settings tab's navigator
  // (`_navigatorKeys[4]`) so hiding the tab while in Settings reparents the
  // live navigator with no rebuild / transition.
  final ValueNotifier<bool> _globalSettingsOpen = ValueNotifier<bool>(false);
  int _lastTabIndex = 0;
  // Which page of the multi-page tab bar is currently visible. Swiping
  // horizontally on the tab bar moves between pages.
  int _currentPage = 0;
  late CupertinoTabController _tabController;

  // ── Split Screen ──────────────────────────────────────────────────────────
  // The committed arrangement (null = single-tab mode). When non-null the shell
  // renders two stacked subwindows instead of the normal tab content.
  _SplitConfig? _splitConfig;
  // The proposed arrangement shown as a live (ghosted) preview while a tab
  // button or window header is being dragged. Cleared on release.
  _SplitConfig? _splitPreview;
  // True between drag-start and drag-end of a tab button / window header.
  bool _splitDragging = false;
  // Measures the content region so a drag's vertical position resolves to the
  // top or bottom half. Lives on whichever shell (normal / split) is mounted.
  final GlobalKey _splitRegionKey = GlobalKey();

  void _openGlobalSettings() {
    if (_globalSettingsOpen.value) return;
    // No route push: the overlay is part of the shell's Stack (built when
    // `_globalSettingsOpen` is true), so the tab bar / sidebar stays visible
    // and there's no full-screen transition. The Settings tab navigator
    // (`_navigatorKeys[4]`) is built fresh here since the tab is hidden.
    _globalSettingsOpen.value = true;
    _showPlusButton.value = false;
    if (mounted) setState(() {});
  }

  void _closeGlobalSettings() {
    if (!_globalSettingsOpen.value) return;
    _globalSettingsOpen.value = false;
    // Reset the Settings stack so the next open starts at the root page.
    _navigatorKeys[4].currentState?.popUntil((r) => r.isFirst);
    _refreshPlusForTab(_lastTabIndex);
    if (mounted) setState(() {});
  }

  /// Android system-back / predictive-back while the Settings overlay is open:
  /// pop within Settings if it has sub-pages, otherwise leave the overlay.
  void _handleSettingsOverlayBack() {
    final nav = _navigatorKeys[4].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      _closeGlobalSettings();
    }
  }

  // ── Split Screen ──────────────────────────────────────────────────────────

  /// The tab paired with [tab] in the current split arrangement.
  int _otherSplitTab(int tab) {
    final cfg = _splitConfig ?? _splitPreview;
    if (cfg == null) return tab;
    return cfg.topTab == tab ? cfg.bottomTab : cfg.topTab;
  }

  String _tabName(int tab) {
    final s = S.of(context);
    switch (tab) {
      case 0:
        return s.tabTasks;
      case 1:
        return s.tabNotes;
      case 2:
        return s.tabCalendar;
      case 3:
        return s.tabRoutines;
      case 5:
        return s.tabFinance;
      case 6:
        return s.tabGoals;
      default:
        return s.tabSettings;
    }
  }

  /// Enters split mode from a tab ⋯ menu: the active tab on top, [withTab]
  /// below.
  void _enterSplitFromMenu(int withTab) {
    final host = _lastTabIndex;
    if (host == withTab) return;
    setState(() {
      _splitConfig = _SplitConfig(topTab: host, bottomTab: withTab);
      _splitPreview = null;
      _splitDragging = false;
    });
  }

  /// Updates the live preview from a drag hovering over the content area.
  void _setSplitPreview(_TabDragPayload p, bool topHalf) {
    final cfg = topHalf
        ? _SplitConfig(
            topTab: p.draggedTab, bottomTab: p.hostTab, draggedTab: p.draggedTab)
        : _SplitConfig(
            topTab: p.hostTab, bottomTab: p.draggedTab, draggedTab: p.draggedTab);
    if (_splitDragging && _splitPreview == cfg) return;
    setState(() {
      _splitDragging = true;
      _splitPreview = cfg;
    });
  }

  /// The drag left the content area (moved back over the tab bar) — drop the
  /// preview so the underlying view shows through again.
  void _onSplitDragLeave() {
    if (_splitPreview != null) setState(() => _splitPreview = null);
  }

  /// Commits the previewed arrangement when a drag is released over the content.
  void _commitSplitPreview(_TabDragPayload p) {
    final preview = _splitPreview ??
        _SplitConfig(topTab: p.hostTab, bottomTab: p.draggedTab);
    setState(() {
      _splitConfig =
          _SplitConfig(topTab: preview.topTab, bottomTab: preview.bottomTab);
      _splitPreview = null;
      _splitDragging = false;
    });
  }

  /// Drag released. When not accepted by the content target (i.e. over the tab
  /// bar / outside), an active split closes, and an entering drag is cancelled.
  void _onSplitDragEnd(_TabDragPayload p, bool accepted) {
    if (accepted) return; // _commitSplitPreview already handled the drop.
    if (_splitConfig != null) {
      _exitSplitTo(p.hostTab);
    } else {
      setState(() {
        _splitPreview = null;
        _splitDragging = false;
      });
    }
  }

  /// Closes the [tabToClose] subwindow and switches fully to the other one,
  /// preserving its in-split state.
  void _closeSplitWindow(int tabToClose) {
    final cfg = _splitConfig;
    if (cfg == null) return;
    _exitSplitTo(_otherSplitTab(tabToClose));
  }

  /// Leaves split mode and shows [tab] full-screen.
  void _exitSplitTo(int tab) {
    setState(() {
      _splitConfig = null;
      _splitPreview = null;
      _splitDragging = false;
      _lastTabIndex = tab;
    });
    widget.settingsController.setLastOpenedTab(tab);
    _tabController.index = _visualForBuiltin(tab);
    _refreshPlusForTab(tab);
  }

  @override
  void initState() {
    super.initState();
    final visible = _computeVisibleIndices();
    // A Space switched by swiping the tab bar should land on the same tab, not
    // on whichever tab the launch preference names.
    final carried = _tabAcrossSpaceSwitch;
    _tabAcrossSpaceSwitch = null;
    _lastTabIndex = carried != null && visible.contains(carried)
        ? carried
        : widget.settingsController.resolveInitialTab(visible);
    final initialVisual = _visualForBuiltin(_lastTabIndex);
    _tabController =
        CupertinoTabController(initialIndex: initialVisual < 0 ? 0 : initialVisual);
    widget.settingsController.addListener(_onSettingsChanged);
    _depthObservers = [
      // Tasks tab: show + unless TaskDetailView is on the stack.
      _DepthObserver(
        trackedRouteName: 'task_detail',
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 0) {
            _showPlusButton.value = trackedCount == 0;
          }
        },
      ),
      // Notes tab: always hide global +; Notes manages its own button.
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 1) _showPlusButton.value = false;
        },
      ),
      // Calendar tab: hide when navigated deeper, and hide entirely when
      // both task and event creation are disabled.
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 2) {
            _showPlusButton.value = depth <= 1 && _calendarPlusAllowed();
          }
        },
      ),
      // Routines tab: hide when navigated deeper.
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 3) _showPlusButton.value = depth <= 1;
        },
      ),
      // Settings tab: always hide +.
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 4) _showPlusButton.value = false;
        },
      ),
      // Finance tab: hide when navigated deeper (categories / budgets).
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 5) _showPlusButton.value = depth <= 1;
        },
      ),
      // Goals tab: hide when navigated deeper (goal detail / editor).
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 6) _showPlusButton.value = depth <= 1;
        },
      ),
    ];
    // Notes (1) and Settings (4) never show the global +. The Calendar tab
    // additionally hides + when both creation toggles are off.
    _showPlusButton.value = _lastTabIndex != 1 &&
        _lastTabIndex != 4 &&
        (_lastTabIndex != 2 || _calendarPlusAllowed());

    // Wire up Plus-button drag drop callbacks. These run regardless of which
    // tab is currently active because a Draggable receives drops anywhere on
    // screen; the target widgets live inside per-tab views.
    _plusDragController.onDropOnList = _handleDropOnList;
    _plusDragController.onDropOnFolder = _handleDropOnFolder;
    _plusDragController.onDropOnSection = _handleDropOnSection;
    _plusDragController.onDropOnDay = _handleDropOnDay;
    _plusDragController.onDropOnNoteFolder = _handleDropOnNoteFolder;
    _plusDragController.onDropOnNotesRoot = _handleDropOnNotesRoot;
    _plusDragController.onDropOnSmartList = _handleDropOnSmartList;
    _plusDragController.onDropOnAddFolderButton =
        _handleDropOnAddFolderButton;
    _plusDragController.onDropOnNotesAddFolderButton =
        _handleDropOnNotesAddFolderButton;

    // First-open-of-a-new-day overdue handling (auto-postpone / review popup).
    // Deferred to after the first frame so the shell (and any unlock) settles
    // before we touch the navigator. HomeShell isn't built until the security
    // gate is unlocked, so this naturally runs post-unlock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeRunOverdueCheck();
    });
  }

  /// Runs at most once per calendar day (across spaces, since the marker lives
  /// in the global settings): if enabled, auto-postpones overdue tasks to
  /// today, or shows the "Overdue Tasks" review popup.
  Future<void> _maybeRunOverdueCheck() async {
    final sc = widget.settingsController;
    if (!sc.autoPostponeOverdue && !sc.showOverdueReview) return;

    final today = DayBoundary.today();
    final todayKey = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    if (sc.lastOverdueCheckDay == todayKey) return;
    // Record immediately so we don't re-prompt within the same day even if the
    // user dismisses without acting.
    await sc.setLastOverdueCheckDay(todayKey);

    final overdue = widget.taskController.overdueTasks;
    if (overdue.isEmpty) return;

    if (sc.autoPostponeOverdue) {
      await widget.taskController
          .postponeTasksToToday(overdue.map((t) => t.id).toList());
      return;
    }
    // Review popup (only when auto-postpone is off).
    if (sc.showOverdueReview && mounted) {
      await showOverdueTasksReview(context, widget.taskController);
    }
  }

  void _handleDropOnAddFolderButton() {
    showCreateFolderListSheet(context, widget.folderController);
  }

  void _handleDropOnNotesAddFolderButton() {
    showCreateNoteFolderSheet(context, widget.noteController);
  }

  void _handleDropOnSmartList(PlusDropSmartList kind) {
    final now = DateTime.now();
    DateTime today() => DateTime(now.year, now.month, now.day);
    DateTime tomorrow() =>
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    // For Upcoming there's no canonical date — fall back to today+2 so
    // the task at least lands in the Upcoming bucket. The user can still
    // edit it from the creation sheet.
    DateTime upcomingDefault() =>
        DateTime(now.year, now.month, now.day).add(const Duration(days: 2));

    switch (kind) {
      case PlusDropSmartList.inbox:
        // Inbox = no list assigned, no date — explicit clear.
        showTaskCreationSheet(
          context,
          widget.taskController,
          widget.folderController,
          settingsController: widget.settingsController,
        );
      case PlusDropSmartList.today:
        showTaskCreationSheet(
          context,
          widget.taskController,
          widget.folderController,
          initialDueDate: today(),
          settingsController: widget.settingsController,
        );
      case PlusDropSmartList.tomorrow:
        showTaskCreationSheet(
          context,
          widget.taskController,
          widget.folderController,
          initialDueDate: tomorrow(),
          settingsController: widget.settingsController,
        );
      case PlusDropSmartList.upcoming:
        showTaskCreationSheet(
          context,
          widget.taskController,
          widget.folderController,
          initialDueDate: upcomingDefault(),
          settingsController: widget.settingsController,
        );
      case PlusDropSmartList.allTasks:
        // All Tasks is a read-only union — defaults to Inbox.
        showTaskCreationSheet(
          context,
          widget.taskController,
          widget.folderController,
          settingsController: widget.settingsController,
        );
    }
  }

  void _handleDropOnList(String listId) {
    final list = widget.folderController.listById(listId);
    if (list?.listType == ListType.birthdays) {
      showContactCreationSheet(
        context,
        widget.contactController,
        listId: listId,
      );
      return;
    }
    showTaskCreationSheet(
      context,
      widget.taskController,
      widget.folderController,
      initialListId: listId,
      settingsController: widget.settingsController,
    );
  }

  void _handleDropOnFolder(String folderId) {
    // Dropping on a folder pre-fills the new task with the folder's chosen
    // default list — or, failing that, the first list inside it. The user can
    // still change the list from the sheet's list picker.
    final resolved = _resolveFolderDefaultList(folderId);
    if (resolved != null) {
      // Route through the list handler so Birthdays lists open the contact
      // creator instead of the task sheet.
      _handleDropOnList(resolved);
      return;
    }
    showTaskCreationSheet(
      context,
      widget.taskController,
      widget.folderController,
      settingsController: widget.settingsController,
    );
  }

  /// Resolves the list a new task should land in when created from inside
  /// [folderId]: the folder's configured `defaultListId` when it still points
  /// at a list in that folder, otherwise the first list directly inside it.
  /// Returns null when the folder has no lists (→ Inbox).
  String? _resolveFolderDefaultList(String folderId) {
    final lists = widget.folderController.listsIn(folderId);
    if (lists.isEmpty) return null;
    final folder = widget.folderController.folderById(folderId);
    final preferred = folder?.defaultListId;
    if (preferred != null && lists.any((l) => l.id == preferred)) {
      return preferred;
    }
    return lists.first.id;
  }

  void _handleDropOnSection(String listId, String sectionId) {
    final list = widget.folderController.listById(listId);
    if (list?.listType == ListType.birthdays) return;
    // Show the standard task sheet but stamp the section id on the new task
    // by intercepting via the controller before/after creation. Simpler:
    // open the sheet and apply the section assignment afterwards. We do it
    // by routing through addTask directly with a minimal sheet — but to
    // keep the UX consistent, we use the sheet and patch the resulting
    // task's section via a follow-up moveTaskToSection call once it appears.
    showTaskCreationSheet(
      context,
      widget.taskController,
      widget.folderController,
      initialListId: listId,
      initialSectionId: sectionId,
      settingsController: widget.settingsController,
    );
  }

  void _handleDropOnDay(DateTime date) {
    // Don't write to _activeDueDate here — that's intended for tab-state
    // (selected day in calendar) and persists until the calendar sheet
    // closes. Just route the chosen date directly into the picker so
    // subsequent +-button taps don't keep re-using this date.
    _showCalendarItemPicker(date);
  }

  void _handleDropOnNoteFolder(String folderId) {
    // Build the placeholder once, outside the route builder, so a route
    // rebuild can't mint a new Note (with a new id) and redirect saves.
    final draft = Note(title: '', content: '', folderId: folderId);
    _navigatorKeys[1].currentState?.push(
      FastRoute<void>(
        settings: const RouteSettings(name: NoteDetailView.routeName),
        builder: (_) => NoteDetailView(
          note: draft,
          controller: widget.noteController,
          isNew: true,
        ),
      ),
    );
  }

  void _handleDropOnNotesRoot() {
    final draft = Note(title: '', content: '');
    _navigatorKeys[1].currentState?.push(
      FastRoute<void>(
        settings: const RouteSettings(name: NoteDetailView.routeName),
        builder: (_) => NoteDetailView(
          note: draft,
          controller: widget.noteController,
          isNew: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_onSettingsChanged);
    _tabController.dispose();
    _activeListId.dispose();
    _activeFolderId.dispose();
    _activeDueDate.dispose();
    _activeCalendarDate.dispose();
    _tasksCollapseSignal.dispose();
    _notesCollapseSignal.dispose();
    _calendarResetSignal.dispose();
    _routinesResetSignal.dispose();
    _financeResetSignal.dispose();
    _activeFinanceMonth.dispose();
    _activeFinanceAccount.dispose();
    _showPlusButton.dispose();
    _plusButtonInset.dispose();
    _globalSettingsOpen.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    // If the page being viewed was emptied (all its tabs removed in Settings),
    // snap to the nearest non-empty page so the user is never stranded on one.
    final navigable = _navigablePageIndices();
    if (navigable.isNotEmpty && !navigable.contains(_currentPage)) {
      _currentPage = navigable.lastWhere((i) => i <= _currentPage,
          orElse: () => navigable.first);
    }
    final visibleIndices = _computeVisibleIndices();

    // Settings tab just became visible while the user is viewing Settings via
    // the global overlay → silently promote the overlay to the real tab. The
    // Settings navigator (`_navigatorKeys[4]`) reparents from the overlay back
    // into the tab scaffold with its stack intact.
    if (_globalSettingsOpen.value && visibleIndices.contains(4)) {
      _globalSettingsOpen.value = false;
      _lastTabIndex = 4;
      _tabController.index = _visualForBuiltin(4);
      _showPlusButton.value = false;
      return;
    }

    if (visibleIndices.contains(_lastTabIndex)) {
      _tabController.index = _visualForBuiltin(_lastTabIndex);
      // Settings toggles may have flipped Calendar's + button visibility.
      if (_lastTabIndex == 2) {
        _showPlusButton.value =
            _depthObservers[2].depth <= 1 && _calendarPlusAllowed();
      }
      return;
    }
    // The active tab was just hidden from the tab bar. Fall back to Tasks (or
    // the first remaining tab) so the scaffold index stays valid.
    final wasSettings = _lastTabIndex == 4;
    final fallback = visibleIndices.contains(0) ? 0 : visibleIndices.first;
    _lastTabIndex = fallback;
    _tabController.index = _visualForBuiltin(fallback);
    // Hiding the Settings tab while the user is in it must not yank them out:
    // open the global Settings overlay instead. The Settings navigator
    // reparents from the (now-removed) tab into the overlay with its stack
    // intact, so there's no transition and the tab bar stays visible. The
    // overlay covers the fallback tab's content, so suppress the + button.
    if (wasSettings) {
      _globalSettingsOpen.value = true;
      _showPlusButton.value = false;
      return;
    }
    switch (fallback) {
      case 0:
        _showPlusButton.value = _depthObservers[0].trackedCount == 0;
      case 1:
        _showPlusButton.value = false;
      default:
        _showPlusButton.value = _depthObservers[fallback].depth <= 1;
    }
  }

  void _onPlusPressed() {
    if (_lastTabIndex == 6) {
      _createGoal();
      return;
    }

    if (_lastTabIndex == 5) {
      showTransactionSheet(
        context,
        widget.financeController,
        initialDate: _activeFinanceMonth.value,
        initialAccountId: _activeFinanceAccount.value,
      );
      return;
    }

    if (_lastTabIndex == 3) {
      _navigatorKeys[3].currentState?.push(
        FastRoute<void>(
          settings: const RouteSettings(name: 'routine_creation'),
          builder: (_) => RoutineCreationView(
            controller: widget.routineController,
          ),
        ),
      );
      return;
    }

    // On Calendar tab: tap of + always routes through the calendar item
    // picker (which gates on the task/event-creation toggles). When no day
    // is selected, default to today so the new item has a date.
    if (_lastTabIndex == 2) {
      final now = DateTime.now();
      final date =
          _activeCalendarDate.value ?? DateTime(now.year, now.month, now.day);
      _showCalendarItemPicker(date);
      return;
    }

    // A Kanban view on top of the Tasks tab handles + taps itself (snaps to
    // the focused/nearest column, then creates a task scoped to it).
    if (_lastTabIndex == 0 &&
        _plusDragController.onKanbanPlusTap != null &&
        _plusDragController.onKanbanPlusTap!()) {
      return;
    }

    // No valid destination for a new task → the + button is grayed and
    // shouldn't fire. Guard here as well as at render time so a stray tap
    // (or programmatic invocation) doesn't open an empty creation sheet.
    if (_lastTabIndex == 0 && !_tasksPlusEnabled()) return;

    // Resolve the target list: the active list if any, otherwise the active
    // folder's default (or first) list when we're browsing inside a folder,
    // otherwise — when Inbox is hidden — the user's configured "default
    // list" or the first available list.
    var initialListId = _activeListId.value;
    // We're creating from inside a folder that has no lists of its own, so the
    // task can't be scoped to a list in that folder and instead falls back to
    // the global default list — warn the user in the sheet.
    final emptyFolderWarning = _activeListId.value == null &&
        _activeFolderId.value != null &&
        _resolveFolderDefaultList(_activeFolderId.value!) == null;
    if (initialListId == null && _activeFolderId.value != null) {
      initialListId = _resolveFolderDefaultList(_activeFolderId.value!);
    }
    if (initialListId == null &&
        widget.settingsController.smartListPrefs.inbox ==
            SmartListVisibility.hidden) {
      initialListId = _resolveInboxFallbackList();
    }

    // When the target is a Birthdays list, open the contact creator instead
    // of the standard task sheet.
    if (initialListId != null) {
      final list = widget.folderController.listById(initialListId);
      if (list?.listType == ListType.birthdays) {
        showContactCreationSheet(
          context,
          widget.contactController,
          listId: initialListId,
        );
        return;
      }
    }

    showTaskCreationSheet(
      context,
      widget.taskController,
      widget.folderController,
      initialListId: initialListId,
      initialDueDate: _activeDueDate.value,
      settingsController: widget.settingsController,
      emptyFolderWarning: emptyFolderWarning,
    );
  }

  /// Opens the goal editor on the Goals tab and saves whatever comes back.
  Future<void> _createGoal() async {
    final created = await showGoalEditor(
      context,
      goalController: widget.goalController,
      taskController: widget.taskController,
      folderController: widget.folderController,
    );
    if (created != null) await widget.goalController.addGoal(created);
  }

  /// Resolves where a new task lands when Inbox is hidden: the user's chosen
  /// default list (if it still exists), otherwise the first list in the
  /// space, otherwise null (which falls through to Inbox — but the +
  /// button is grayed in that case so we shouldn't get here).
  String? _resolveInboxFallbackList() {
    final preferred = widget.settingsController.defaultTaskListId;
    if (preferred != null &&
        widget.folderController.listById(preferred) != null) {
      return preferred;
    }
    final lists = widget.folderController.lists;
    return lists.isEmpty ? null : lists.first.id;
  }

  /// Whether the Tasks-tab + button has any task creation target. False when
  /// Inbox is hidden AND there's no default list, no smart-list with a
  /// natural date, and no user lists in the active space — i.e. nowhere a
  /// new task could go.
  bool _tasksPlusEnabled() {
    final prefs = widget.settingsController.smartListPrefs;
    // Inbox visible → tapping + always falls back to Inbox.
    if (prefs.inbox != SmartListVisibility.hidden) return true;
    // A folder context can resolve to a list.
    if (_activeFolderId.value != null &&
        widget.folderController.listsIn(_activeFolderId.value!).isNotEmpty) {
      return true;
    }
    // Default list set and still exists.
    if (_resolveInboxFallbackList() != null) return true;
    return false;
  }

  Future<void> _showCalendarItemPicker(DateTime date) async {
    final allowTasks = widget.settingsController.calendarAllowCreatingTasks;
    final allowEvents = widget.settingsController.calendarAllowCreatingEvents;
    if (!allowTasks && !allowEvents) return;

    if (allowTasks && !allowEvents) {
      showTaskCreationSheet(
        context,
        widget.taskController,
        widget.folderController,
        initialDueDate: date,
        settingsController: widget.settingsController,
      );
      return;
    }
    if (allowEvents && !allowTasks) {
      showEventCreationSheet(
        context,
        widget.eventController,
        initialDate: date,
        googleCalendarController: widget.googleCalendarController,
        deviceCalendarController: widget.deviceCalendarController,
      );
      return;
    }

    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      title: s.addToCalendar,
      options: [
        SelectionMenuOption(value: 'task', label: s.taskOption),
        SelectionMenuOption(value: 'event', label: s.eventOption),
      ],
    );
    if (!mounted) return;
    if (choice == 'task') {
      showTaskCreationSheet(
        context,
        widget.taskController,
        widget.folderController,
        initialDueDate: date,
        settingsController: widget.settingsController,
      );
    } else if (choice == 'event') {
      showEventCreationSheet(
        context,
        widget.eventController,
        initialDate: date,
        googleCalendarController: widget.googleCalendarController,
        deviceCalendarController: widget.deviceCalendarController,
      );
    }
  }

  /// Routes a tab-bar tap to either the built-in tap handler or the shortcut
  /// router. For shortcuts, the CupertinoTabScaffold will still bump the
  /// controller's index to [visualIdx] — we reset it to the previous
  /// position in a post-frame callback so the shortcut slot never shows as
  /// active.
  void _handleTabTap(int visualIdx) {
    final pageItems = _pageItems();
    if (visualIdx < 0 || visualIdx >= pageItems.length) return;
    final item = pageItems[visualIdx];
    if (item.kind == TabKind.shortcut) {
      final prev = _tabController.index;
      _openShortcut(item);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tabController.index == visualIdx) {
          _tabController.index = prev;
        }
      });
      return;
    }
    if (item.builtinIndex != null) {
      _onTabTapped(item.builtinIndex!);
    }
  }

  void _onTabTapped(int tappedIndex) {
    // Tapping any tab while the global Settings overlay is open leaves
    // Settings and highlights that tab.
    if (_globalSettingsOpen.value) {
      _globalSettingsOpen.value = false;
      _navigatorKeys[4].currentState?.popUntil((r) => r.isFirst);
    }
    if (tappedIndex == _lastTabIndex) {
      _navigatorKeys[tappedIndex].currentState
          ?.popUntil((route) => route.isFirst);
      if (tappedIndex == 0) _tasksCollapseSignal.value++;
      if (tappedIndex == 1) _notesCollapseSignal.value++;
      if (tappedIndex == 2) _calendarResetSignal.value++;
      if (tappedIndex == 3) _routinesResetSignal.value++;
      if (tappedIndex == 5) _financeResetSignal.value++;
    }
    _refreshPlusForTab(tappedIndex);
    final changed = tappedIndex != _lastTabIndex;
    _lastTabIndex = tappedIndex;
    widget.settingsController.setLastOpenedTab(tappedIndex);
    // The wide (sidebar) layout's IndexedStack is driven by `_lastTabIndex`
    // through `_buildShell`, which otherwise only rebuilds on a
    // settingsController notify. `setLastOpenedTab` deliberately doesn't
    // notify, so without an explicit rebuild here a sidebar tab tap would
    // update `_lastTabIndex` but leave the visible tab unchanged until some
    // unrelated rebuild flushed it. Rebuild so the switch is immediate.
    // (Narrow layout drives switching through CupertinoTabController and is
    // unaffected by this extra rebuild.)
    if (changed && mounted) setState(() {});
  }

  /// Sets the floating + button visibility for the given built-in tab.
  void _refreshPlusForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        _showPlusButton.value = _depthObservers[0].trackedCount == 0;
      case 1:
        _showPlusButton.value = false;
      case 2:
        _showPlusButton.value =
            _depthObservers[2].depth <= 1 && _calendarPlusAllowed();
      case 4:
        _showPlusButton.value = false;
      default:
        _showPlusButton.value = _depthObservers[tabIndex].depth <= 1;
    }
  }

  /// Handles a tap on the bespoke single-item tab bar (shown for a one-tab
  /// page when other pages exist).
  void _handleSingleBarTap(TabItem item, int logicalIdx) {
    if (item.kind == TabKind.shortcut) {
      _openShortcut(item);
      return;
    }
    _onTabTapped(item.builtinIndex ?? logicalIdx);
  }

  /// Whether the floating + button is allowed on the Calendar tab. Off when
  /// both task and event creation are disabled in Settings → Calendar.
  bool _calendarPlusAllowed() =>
      widget.settingsController.calendarAllowCreatingTasks ||
      widget.settingsController.calendarAllowCreatingEvents;

  /// Builtin tab indices appearing in the currently visible page's items,
  /// in display order. Shortcut items don't count toward this — they're
  /// rendered on the bar but don't have their own navigator slot.
  List<int> _computeVisibleIndices() {
    final builtins = <int>[];
    for (final item in _pageItems()) {
      if (item.kind == TabKind.builtin && item.builtinIndex != null) {
        builtins.add(item.builtinIndex!);
      }
    }
    return builtins.isEmpty ? [0] : builtins;
  }

  /// All items on the current page (built-ins + shortcuts), in display order.
  /// The live, rendered pages — disabled tabs filtered out.
  List<List<TabItem>> _activePages() =>
      widget.settingsController.tabBarConfig.active.pages;

  List<TabItem> _pageItems() {
    final pages = _activePages();
    if (pages.isEmpty) return const [];
    // In spaces mode the bar always shows the first non-empty page — swiping
    // means "switch Space", so there is no way to reach the other pages and
    // leaving the user parked on one would strand them.
    if (_swipesSpaces) {
      final navigable = _navigablePageIndices();
      return pages[navigable.isEmpty ? 0 : navigable.first];
    }
    final pageIdx = _currentPage.clamp(0, pages.length - 1);
    return pages[pageIdx];
  }

  /// Indices of pages that hold at least one tab — the only pages the user can
  /// swipe to / that earn a page-indicator dot. Empty pages are skipped so the
  /// dots never count a page the user can't actually reach.
  List<int> _navigablePageIndices() {
    final pages = _activePages();
    final result = <int>[];
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].isNotEmpty) result.add(i);
    }
    return result;
  }

  /// Returns the visual position (index into `_pageItems()`) of the first
  /// built-in entry whose logical index matches [logicalIdx], or 0 if none.
  /// Used to keep `_tabController.index` in sync with the active built-in
  /// tab when shortcuts share the bar.
  int _visualForBuiltin(int logicalIdx) {
    final items = _pageItems();
    for (var i = 0; i < items.length; i++) {
      if (items[i].kind == TabKind.builtin &&
          items[i].builtinIndex == logicalIdx) {
        return i;
      }
    }
    return 0;
  }

  /// Pushes a shortcut's target view on the relevant navigator and switches
  /// the active tab to that navigator. Used when the user taps a shortcut
  /// item in the tab bar.
  void _openShortcut(TabItem item) {
    final target = item.shortcutTarget;
    if (target == null) return;

    // Map shortcut → owning built-in tab (Tasks for tasks/lists/folders,
    // Notes for note folders).
    final ownerLogicalIdx = target == ShortcutTarget.noteFolder ? 1 : 0;
    final navigator = _navigatorKeys[ownerLogicalIdx].currentState;
    if (navigator == null) return;

    // Pop back to root on the target tab so the shortcut consistently
    // shows the target view at the top of the stack.
    navigator.popUntil((route) => route.isFirst);

    // Route the shortcut to the correct view via the existing per-tab
    // browse routes. The shortcut router knows how to map each target to
    // the matching view constructor.
    pushShortcut(
      navigator: navigator,
      target: target,
      shortcutId: item.shortcutId,
      taskController: widget.taskController,
      folderController: widget.folderController,
      noteController: widget.noteController,
      contactController: widget.contactController,
      activeDueDate: _activeDueDate,
      activeListId: _activeListId,
    );

    // Switch the visible tab to the shortcut's owner. The user lands on
    // the target view inside that tab's navigator.
    final visibleIndices = _computeVisibleIndices();
    if (visibleIndices.contains(ownerLogicalIdx)) {
      _onTabTapped(ownerLogicalIdx);
      _tabController.index = _visualForBuiltin(ownerLogicalIdx);
    } else {
      // Owner tab isn't on this page — switch to whichever page has it.
      final pages = _activePages();
      for (var p = 0; p < pages.length; p++) {
        if (pages[p].any((it) =>
            it.kind == TabKind.builtin && it.builtinIndex == ownerLogicalIdx)) {
          setState(() => _currentPage = p);
          _onTabTapped(ownerLogicalIdx);
          _tabController.index = _visualForBuiltin(ownerLogicalIdx);
          break;
        }
      }
    }
  }

  BottomNavigationBarItem _renderTabItem(
      BuildContext context, TabItem item, bool hideLabels, bool overlayOpen) {
    if (item.kind == TabKind.builtin && item.builtinIndex != null) {
      return _tabItem(context, item.builtinIndex!, hideLabels, overlayOpen);
    }
    // Shortcut item.
    final s = S.of(context);
    final label = item.customLabel ?? _defaultShortcutLabel(s, item);
    final icon = _shortcutIcon(item, context);
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: icon,
      ),
      activeIcon: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: icon,
      ),
      label: hideLabels ? null : label,
    );
  }

  static String _defaultShortcutLabel(S s, TabItem item) {
    switch (item.shortcutTarget) {
      case ShortcutTarget.smartInbox:
        return s.inbox;
      case ShortcutTarget.smartToday:
        return s.today;
      case ShortcutTarget.smartTomorrow:
        return s.tomorrow;
      case ShortcutTarget.smartUpcoming:
        return s.upcoming;
      case ShortcutTarget.smartAllTasks:
        return s.allTasks;
      case ShortcutTarget.smartCompleted:
        return s.completed;
      case ShortcutTarget.smartTrash:
        return s.trash;
      case ShortcutTarget.list:
        return s.list;
      case ShortcutTarget.folder:
      case ShortcutTarget.noteFolder:
        return s.folder;
      default:
        return s.tabKindShortcut;
    }
  }

  Widget _shortcutIcon(TabItem item, BuildContext context) {
    switch (item.shortcutTarget) {
      case ShortcutTarget.smartInbox:
        return const ImageIcon(AssetImage('assets/icons/inbox.png'), size: 24);
      case ShortcutTarget.smartToday:
        return const ImageIcon(AssetImage('assets/icons/today.png'), size: 24);
      case ShortcutTarget.smartTomorrow:
        return Icon(CupertinoIcons.sun_max,
            size: 24, color: CupertinoColors.systemOrange.resolveFrom(context));
      case ShortcutTarget.smartUpcoming:
        return const ImageIcon(
            AssetImage('assets/icons/upcoming.png'), size: 24);
      case ShortcutTarget.smartAllTasks:
        return const Icon(CupertinoIcons.tray_full, size: 24);
      case ShortcutTarget.smartCompleted:
        return const Icon(CupertinoIcons.checkmark_circle_fill, size: 24);
      case ShortcutTarget.smartTrash:
        return const Icon(CupertinoIcons.trash, size: 24);
      case ShortcutTarget.list:
        return const ImageIcon(AssetImage('assets/icons/list.png'), size: 24);
      case ShortcutTarget.folder:
      case ShortcutTarget.noteFolder:
        return const ImageIcon(AssetImage('assets/icons/folder.png'), size: 24);
      default:
        return const Icon(CupertinoIcons.square, size: 24);
    }
  }

  BottomNavigationBarItem _tabItem(BuildContext context, int logicalIdx,
      bool hideLabels,
      [bool deselectAll = false]) {
    final s = S.of(context);
    // When the global Settings overlay is active, swap the active icon for the
    // outline (inactive) version so the active tab matches the others.
    Widget activeIcon(String asset) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ImageIcon(
            AssetImage(asset),
            color: deselectAll ? null : AppColors.accent,
          ),
        );
    switch (logicalIdx) {
      case 0:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(AssetImage('assets/icons/tab_bar/tasks.png')),
          ),
          activeIcon: activeIcon('assets/icons/tab_bar/tasks.png'),
          label: hideLabels ? null : s.tabTasks,
        );
      case 1:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(AssetImage('assets/icons/tab_bar/notes.png')),
          ),
          activeIcon: activeIcon('assets/icons/tab_bar/notes.png'),
          label: hideLabels ? null : s.tabNotes,
        );
      case 2:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child:
                ImageIcon(AssetImage('assets/icons/tab_bar/calendar.png')),
          ),
          activeIcon: activeIcon('assets/icons/tab_bar/calendar.png'),
          label: hideLabels ? null : s.tabCalendar,
        );
      case 3:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child:
                ImageIcon(AssetImage('assets/icons/tab_bar/routines.png')),
          ),
          activeIcon: activeIcon('assets/icons/tab_bar/routines.png'),
          label: hideLabels ? null : s.tabRoutines,
        );
      case 6:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(CupertinoIcons.flag),
          ),
          activeIcon: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              CupertinoIcons.flag_fill,
              color: deselectAll ? null : AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabGoals,
        );
      case 5:
        // No bespoke PNG for Finance yet — the Cupertino glyph matches the
        // outline weight of the other tab icons closely enough.
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(CupertinoIcons.money_dollar_circle),
          ),
          activeIcon: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              CupertinoIcons.money_dollar_circle_fill,
              color: deselectAll ? null : AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabFinance,
        );
      default:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(AssetImage('assets/icons/tab_bar/settings.png')),
          ),
          activeIcon: activeIcon('assets/icons/tab_bar/settings.png'),
          label: hideLabels ? null : s.tabSettings,
        );
    }
  }

  Widget _tabContent(BuildContext context, int logicalIdx) {
    return switch (logicalIdx) {
      0 => TasksView(
          controller: widget.taskController,
          folderController: widget.folderController,
          contactController: widget.contactController,
          settingsController: widget.settingsController,
          routineController: widget.routineController,
          activeListId: _activeListId,
          activeDueDate: _activeDueDate,
          activeFolderId: _activeFolderId,
          collapseSignal: _tasksCollapseSignal,
          backupService: widget.backupService,
          db: SpaceManagerProvider.of(context).db,
          noteController: widget.noteController,
          eventController: widget.eventController,
        ),
      1 => NotesView(
          controller: widget.noteController,
          collapseSignal: _notesCollapseSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
          db: SpaceManagerProvider.of(context).db,
          taskController: widget.taskController,
          folderController: widget.folderController,
          eventController: widget.eventController,
        ),
      2 => CalendarView(
          controller: widget.taskController,
          folderController: widget.folderController,
          eventController: widget.eventController,
          contactController: widget.contactController,
          resetSignal: _calendarResetSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
          onDaySelected: (d) => _activeCalendarDate.value = d,
          db: SpaceManagerProvider.of(context).db,
          noteController: widget.noteController,
          routineController: widget.routineController,
          googleCalendarController: widget.googleCalendarController,
          deviceCalendarController: widget.deviceCalendarController,
        ),
      3 => RoutinesView(
          controller: widget.routineController,
          resetSignal: _routinesResetSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
          db: SpaceManagerProvider.of(context).db,
          taskController: widget.taskController,
          folderController: widget.folderController,
          noteController: widget.noteController,
          eventController: widget.eventController,
        ),
      6 => GoalsView(
          controller: widget.goalController,
          taskController: widget.taskController,
          folderController: widget.folderController,
          settingsController: widget.settingsController,
        ),
      5 => FinanceView(
          controller: widget.financeController,
          settingsController: widget.settingsController,
          resetSignal: _financeResetSignal,
          activeMonth: _activeFinanceMonth,
          activeAccount: _activeFinanceAccount,
        ),
      _ => SettingsView(
          controller: widget.settingsController,
          backupService: widget.backupService,
          securityService: widget.securityService,
          googleCalendarController: widget.googleCalendarController,
          deviceCalendarController: widget.deviceCalendarController,
          // Shown reactively only while Settings is the global overlay (tab
          // hidden); as a normal tab the listenable stays false → no button.
          onClose: _closeGlobalSettings,
          showCloseButton: _globalSettingsOpen,
        ),
    };
  }

  /// The Settings overlay layer: rendered above the tab content but inset to
  /// leave the tab bar (narrow) or the sidebar (wide) visible, so hiding the
  /// Settings tab — or opening Settings from another tab's ⋯ menu — keeps the
  /// bar on screen with no tab highlighted instead of a full-screen cover.
  Widget _buildSettingsOverlay(
      BuildContext context, bool isWide, bool hideLabels, bool hasBottomBar) {
    return ValueListenableBuilder<bool>(
      valueListenable: _globalSettingsOpen,
      builder: (context, open, _) {
        // Guard against ever building `_navigatorKeys[4]` in two places at
        // once: when Settings is a visible tab the scaffold/sidebar owns it.
        if (!open || _computeVisibleIndices().contains(4)) {
          return const SizedBox.shrink();
        }
        final double left = isWide ? (hideLabels ? 72.0 : 200.0) : 0.0;
        final hasBar = !isWide && hasBottomBar;
        final double bottom =
            hasBar ? 50 + MediaQuery.paddingOf(context).bottom : 0.0;
        final overlay = CupertinoTabView(
          navigatorKey: _navigatorKeys[4],
          navigatorObservers: [_depthObservers[4]],
          builder: (ctx) => _tabContent(ctx, 4),
        );
        return Positioned(
          left: left,
          top: 0,
          right: 0,
          bottom: bottom,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _handleSettingsOverlayBack();
            },
            // The overlay already sits above the tab bar, which owns the
            // bottom safe-area inset. Zero out the inset inside so the
            // Settings page's own SafeArea doesn't add a second one — that
            // double-count left a white gap between the content and the bar.
            child: hasBar
                ? MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: overlay,
                  )
                : overlay,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Task rows become draggable (onto calendar days) only when an active
    // split pairs Tasks with Calendar.
    final cfg = _splitConfig;
    final taskDragEnabled = cfg != null &&
        {cfg.topTab, cfg.bottomTab}.containsAll(const {0, 2});
    return UndoScope(
      controller: _undoController,
      child: PlusDragScope(
        controller: _plusDragController,
        child: PlusButtonInsetScope(
          inset: _plusButtonInset,
          child: TaskDragScope(
            enabled: taskDragEnabled,
            onDropOnDay: _setTaskDueDate,
            child: _buildShell(context),
          ),
        ),
      ),
    );
  }

  /// Sets [taskId]'s due date to [date] — the effect of dropping a task onto a
  /// calendar day in split mode.
  void _setTaskDueDate(String taskId, DateTime date) {
    final task = widget.taskController.taskById(taskId);
    if (task == null) return;
    final normalized = DateTime(date.year, date.month, date.day);
    widget.taskController.updateTask(task.copyWith(dueDate: normalized));
  }

  Widget _buildShell(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) {
        final hideLabels = widget.settingsController.hideTabLabels;
        final visibleIndices = _computeVisibleIndices();
        // Desktop (macOS / Linux / Windows) always uses the iPad sidebar
        // layout — the window is resizable and even a "small" desktop window
        // has more chrome room than a phone. On iOS/Android we keep the
        // 700 px threshold so iPhone stays on the bottom tab bar.
        final isWide = PlatformCapabilities.isDesktop ||
            MediaQuery.sizeOf(context).width >= 700;

        // Committed split mode renders a wholly different two-pane shell.
        if (_splitConfig != null) {
          return _buildSplitShell(context, _splitConfig!, hideLabels, isWide);
        }

        final navigablePages = _navigablePageIndices();
        // Only pages that actually hold tabs count toward the multi-page UI —
        // empty pages get no dot and can't be swiped to.
        final hasMultiplePages = navigablePages.length > 1;
        // Spaces mode swaps what the bar's swipe (and its dots) mean.
        final swipesSpaces = _swipesSpaces;
        final spaces = SpaceManagerProvider.maybeOf(context)?.spaces ??
            const <Space>[];
        final activeSpaceId =
            SpaceManagerProvider.maybeOf(context)?.activeSpaceId;
        final activeSpaceIndex =
            spaces.indexWhere((sp) => sp.id == activeSpaceId);
        // Whether the bar has something to swipe between at all — pages in
        // pages mode, spaces in spaces mode. Drives both the dots and the
        // "keep a bar even for a single tab" decision.
        final swipeable =
            swipesSpaces ? spaces.length > 1 : hasMultiplePages;
        final pageItems = _pageItems();
        // The bottom tab bar disappears entirely only when there's a single
        // reachable page holding a single tab — then the app reads as one
        // screen. As soon as there's more than one non-empty page we keep a bar
        // so the user can swipe between pages, even with just one tab on a page.
        final singleNoBar = !isWide && pageItems.length <= 1 && !swipeable;
        // A page that holds a single tab while other non-empty pages exist.
        // CupertinoTabBar requires ≥2 items, so this case gets a bespoke
        // one-item bar instead of CupertinoTabScaffold.
        final customSingleBar = !isWide && swipeable && pageItems.length < 2;
        final hasBottomBar = !isWide && !singleNoBar;

        // The lone item (and the built-in tab it drives) for the custom bar.
        final singleBarItem = pageItems.isNotEmpty
            ? pageItems.first
            : TabItem.builtin(visibleIndices.first);
        var singleBarLogical = visibleIndices.first;
        if (singleBarItem.kind == TabKind.builtin &&
            singleBarItem.builtinIndex != null) {
          singleBarLogical = singleBarItem.builtinIndex!;
        } else if (singleBarItem.kind == TabKind.shortcut) {
          singleBarLogical =
              singleBarItem.shortcutTarget == ShortcutTarget.noteFolder ? 1 : 0;
        }

        return Stack(
          children: [
            if (isWide)
              _WideLayout(
                visibleIndices: visibleIndices,
                hideLabels: hideLabels,
                lastTabIndex: _lastTabIndex,
                // While the Settings overlay is open no sidebar tile reads as
                // selected — the user is in Settings, not in any tab.
                showSelection: !_globalSettingsOpen.value,
                navigatorKeys: _navigatorKeys,
                depthObservers: _depthObservers,
                tabItem: (ctx, i) => _tabItem(ctx, i, hideLabels),
                tabContent: _tabContent,
                onTap: _onTabTapped,
              )
            else if (singleNoBar)
              // Single-tab mode: the tab bar disappears entirely so the user
              // perceives the app as a single screen, not "one tab of many".
              CupertinoTabView(
                navigatorKey: _navigatorKeys[visibleIndices.first],
                navigatorObservers: [
                  _depthObservers[visibleIndices.first],
                ],
                builder: (ctx) =>
                    _tabContent(ctx, visibleIndices.first),
              )
            else if (customSingleBar)
              // One tab on this page, but other pages exist — keep a bar at the
              // bottom (drawn separately below) and reserve room for it so the
              // content isn't hidden behind it.
              Builder(
                builder: (ctx) {
                  final mq = MediaQuery.of(ctx);
                  return MediaQuery(
                    data: mq.copyWith(
                      padding: mq.padding
                          .copyWith(bottom: mq.padding.bottom + 50),
                    ),
                    child: CupertinoTabView(
                      navigatorKey: _navigatorKeys[singleBarLogical],
                      navigatorObservers: [_depthObservers[singleBarLogical]],
                      builder: (c) => _tabContent(c, singleBarLogical),
                    ),
                  );
                },
              )
            else
              ValueListenableBuilder<bool>(
                valueListenable: _globalSettingsOpen,
                builder: (context, overlayOpen, _) {
                  // When the global Settings overlay is on screen, recolor the
                  // active tab to match inactive ones so every tab reads as
                  // "not selected" — the user is in Settings, not in any tab.
                  final activeColor = overlayOpen
                      ? CupertinoColors.secondaryLabel
                      : CupertinoColors.label;
                  // Render all page items (built-ins AND shortcuts) on
                  // the bar. Shortcut taps push the target route on the
                  // owning navigator and revert the controller index so the
                  // shortcut slot itself never appears "selected".
                  final pageItems = _pageItems();
                  return CupertinoTabScaffold(
                    controller: _tabController,
                    tabBar: CupertinoTabBar(
                      activeColor: activeColor,
                      inactiveColor: CupertinoColors.secondaryLabel,
                      backgroundColor:
                          const CupertinoDynamicColor.withBrightness(
                        color: Color(0xF0F9F9F9),
                        darkColor: Color(0xF01D1D1D),
                      ),
                      onTap: (visualIdx) => _handleTabTap(visualIdx),
                      items: pageItems
                          .map((it) =>
                              _renderTabItem(context, it, hideLabels, overlayOpen))
                          .toList(),
                    ),
                    tabBuilder: (context, visualIdx) {
                      final item = pageItems[visualIdx];
                      if (item.kind != TabKind.builtin ||
                          item.builtinIndex == null) {
                        // Shortcut slot never displays its own content — the
                        // tap handler pushes onto a built-in's navigator and
                        // immediately switches back. A stub is fine here.
                        return const SizedBox.shrink();
                      }
                      final logicalIdx = item.builtinIndex!;
                      return CupertinoTabView(
                        navigatorKey: _navigatorKeys[logicalIdx],
                        navigatorObservers: [_depthObservers[logicalIdx]],
                        builder: (ctx) => _tabContent(ctx, logicalIdx),
                      );
                    },
                  );
                },
              ),
            // Bespoke one-item bar for a single-tab page when other pages
            // exist. Drawn here (above the content, below the swipe overlay)
            // so the user can still swipe to other pages.
            if (customSingleBar)
              ValueListenableBuilder<bool>(
                valueListenable: _globalSettingsOpen,
                builder: (context, overlayOpen, _) {
                  final color = (overlayOpen
                          ? CupertinoColors.secondaryLabel
                          : CupertinoColors.label)
                      .resolveFrom(context);
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SingleTabBar(
                      item: _renderTabItem(
                          context, singleBarItem, hideLabels, overlayOpen),
                      color: color,
                      onTap: () =>
                          _handleSingleBarTap(singleBarItem, singleBarLogical),
                    ),
                  );
                },
              ),
            // Global Settings overlay — leaves the tab bar / sidebar visible.
            _buildSettingsOverlay(context, isWide, hideLabels, hasBottomBar),
            // Multi-page tab bar swipe overlay — covers the tab bar area and
            // detects horizontal pan to switch between (non-empty) pages.
            // Active whenever there's more than one non-empty page and we're in
            // the narrow (bottom tab bar) layout.
            if (!isWide && swipeable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 50 + MediaQuery.paddingOf(context).bottom,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // In spaces mode the drag moves the screen as it happens, so
                  // the gesture has to be tracked rather than just measured at
                  // the end. Page mode keeps the flick it always had — pages
                  // live inside one shell and swap without a transition.
                  onHorizontalDragStart:
                      _swipesSpaces ? (_) => _spaceDragOffset = 0 : null,
                  onHorizontalDragUpdate: _swipesSpaces
                      ? (d) {
                          _spaceDragOffset += d.delta.dx;
                          final width = MediaQuery.sizeOf(context).width;
                          if (width <= 0) return;
                          // Positive fraction = towards the next space.
                          SpaceSwitchTransition.maybeOf(context)
                              ?.dragTo(-_spaceDragOffset / width);
                        }
                      : null,
                  onHorizontalDragEnd: (d) {
                    final vel = d.primaryVelocity ?? 0;
                    if (!_swipesSpaces) {
                      if (vel.abs() < 200) return;
                      _switchPage(vel < 0 ? 1 : -1);
                      return;
                    }
                    final width = MediaQuery.sizeOf(context).width;
                    final dragged = width > 0 ? _spaceDragOffset / width : 0.0;
                    _spaceDragOffset = 0;
                    // Commit on a flick or on a drag past a third of the
                    // screen; anything less springs back.
                    final flick = vel.abs() >= 200;
                    final far = dragged.abs() >= 0.33;
                    if (!flick && !far) {
                      SpaceSwitchTransition.maybeOf(context)?.cancelDrag();
                      return;
                    }
                    final delta =
                        flick ? (vel < 0 ? 1 : -1) : (dragged < 0 ? 1 : -1);
                    _switchSpace(delta);
                  },
                  onHorizontalDragCancel: _swipesSpaces
                      ? () {
                          _spaceDragOffset = 0;
                          SpaceSwitchTransition.maybeOf(context)?.cancelDrag();
                        }
                      : null,
                ),
              ),
            // Indicator dots just above the tab bar: one per non-empty page,
            // or one per Space when the bar swipes spaces.
            if (!isWide && swipeable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 50 + MediaQuery.paddingOf(context).bottom + 2,
                child: IgnorePointer(
                  child: _PageDots(
                    count:
                        swipesSpaces ? spaces.length : navigablePages.length,
                    current: swipesSpaces
                        ? activeSpaceIndex.clamp(0, spaces.length - 1)
                        : navigablePages
                            .indexOf(_currentPage)
                            .clamp(0, navigablePages.length - 1),
                  ),
                ),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: _showPlusButton,
              builder: (context, show, _) {
                if (!show) return const SizedBox.shrink();
                final baseBottom = isWide
                    ? 24.0
                    : !hasBottomBar
                        ? MediaQuery.paddingOf(context).bottom + 16
                        : 50 + MediaQuery.paddingOf(context).bottom + 12;
                return ValueListenableBuilder<double>(
                  valueListenable: _plusButtonInset,
                  builder: (context, lift, _) => ListenableBuilder(
                    // Listen to FolderController too so deleting the last list
                    // (which can swing the + button enabled → disabled) repaints
                    // immediately instead of waiting for the next rebuild.
                    listenable: Listenable.merge([
                      _undoController,
                      widget.settingsController,
                      widget.folderController,
                      _activeListId,
                      _activeFolderId,
                    ]),
                    builder: (context, _) {
                      final undoLift =
                          _undoController.pending != null ? 64.0 : 0.0;
                      // Only the Tasks tab can render the disabled state — the
                      // other tabs always have somewhere to create into.
                      final plusEnabled = _lastTabIndex != 0 ||
                          _plusDragController.onKanbanPlusTap != null ||
                          _tasksPlusEnabled();
                      // Per-tab + button placement (falls back to the global
                      // side) and user-configurable size. In the wide layout
                      // the left edge is taken by the sidebar, so the button
                      // always stays on the right there.
                      final onLeft = !isWide &&
                          widget.settingsController
                                  .plusButtonSideForTab(_lastTabIndex) ==
                              PlusButtonSide.left;
                      final scale = widget.settingsController.plusButtonScale;
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        left: onLeft ? 20 : null,
                        right: onLeft ? null : 20,
                        bottom: baseBottom + lift + undoLift,
                        child: _PlusButton(
                          onPressed: _onPlusPressed,
                          enabled: plusEnabled,
                          scale: scale,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: isWide
                  ? 0
                  : !hasBottomBar
                      ? MediaQuery.paddingOf(context).bottom
                      : 50 + MediaQuery.paddingOf(context).bottom,
              child: UndoBanner(controller: _undoController),
            ),
            // ── Split Screen entry (drag a tab button into the view) ────────
            // Only in the narrow bottom-bar layout, and only when the active
            // tab has a split partner (Tasks↔Calendar).
            ..._buildSplitEntryOverlays(context, hasBottomBar && !isWide),
          ],
        );
      },
    );
  }

  /// Overlays that power entering split mode by dragging a tab-bar button: an
  /// invisible long-press-draggable handle over the partner tab's slot, a
  /// translucent drop region over the content (to resolve top/bottom half), and
  /// the live ghosted preview. Returns an empty list when unavailable.
  List<Widget> _buildSplitEntryOverlays(BuildContext context, bool narrowBar) {
    if (!narrowBar || !widget.settingsController.splitScreenDragAvailable) {
      return const [];
    }
    final slot = _partnerTabSlot();
    if (slot == null) return const [];
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = 50 + bottomInset;
    final width = MediaQuery.sizeOf(context).width;
    final slotWidth = width / slot.itemCount;
    final payload =
        _TabDragPayload(draggedTab: slot.partnerTab, hostTab: slot.hostTab);

    return [
      // Drop region over the content (everything above the tab bar).
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: barHeight,
        child: _SplitDropRegion(
          regionKey: _splitRegionKey,
          onMove: _setSplitPreview,
          onLeave: _onSplitDragLeave,
          onAccept: _commitSplitPreview,
        ),
      ),
      // Live preview (ghosted) while dragging over the content.
      if (_splitDragging && _splitPreview != null)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: barHeight,
          child: IgnorePointer(
            child: _SplitPreview(
              config: _splitPreview!,
              topName: _tabName(_splitPreview!.topTab),
              bottomName: _tabName(_splitPreview!.bottomTab),
            ),
          ),
        ),
      // Invisible long-press-drag handle over the partner tab's slot. It also
      // forwards a normal tap so the tab still switches as usual.
      Positioned(
        left: slot.visualIndex * slotWidth,
        width: slotWidth,
        bottom: 0,
        height: barHeight,
        // The draggable must be the outer widget so its long-press recognizer
        // is actually in the hit-test path; the inner opaque GestureDetector
        // gives the area a hittable surface (and forwards a plain tap so the
        // tab still switches normally).
        child: LongPressDraggable<_TabDragPayload>(
          data: payload,
          feedback: _SplitTabDragFeedback(label: _tabName(slot.partnerTab)),
          onDragStarted: () => setState(() => _splitDragging = true),
          onDragEnd: (d) => _onSplitDragEnd(payload, d.wasAccepted),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _onTabTapped(slot.partnerTab);
              _tabController.index = _visualForBuiltin(slot.partnerTab);
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ];
  }

  /// Resolves the partner tab (and its tab-bar slot) for entering split mode
  /// from the active tab. Only the Tasks↔Calendar pair is supported, and both
  /// must be present on the current tab-bar page.
  _PartnerSlot? _partnerTabSlot() {
    int? partner;
    if (_lastTabIndex == 0) {
      partner = 2;
    } else if (_lastTabIndex == 2) {
      partner = 0;
    }
    if (partner == null) return null;
    final items = _pageItems();
    var partnerVisual = -1;
    var hostVisual = -1;
    for (var i = 0; i < items.length; i++) {
      if (items[i].kind == TabKind.builtin) {
        if (items[i].builtinIndex == partner) partnerVisual = i;
        if (items[i].builtinIndex == _lastTabIndex) hostVisual = i;
      }
    }
    if (partnerVisual < 0 || hostVisual < 0) return null;
    return _PartnerSlot(
      partnerTab: partner,
      hostTab: _lastTabIndex,
      visualIndex: partnerVisual,
      itemCount: items.length,
    );
  }

  // ── Split shell (two stacked subwindows) ──────────────────────────────────

  Widget _buildSplitShell(
      BuildContext context, _SplitConfig cfg, bool hideLabels, bool isWide) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = 50 + bottomInset;
    final separator = Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
    // A solid backdrop so the status-bar strip (and any home-indicator gap)
    // isn't a black void; it also reads as a continuation of the top pane's
    // header bar behind the system clock / battery icons.
    return ColoredBox(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      child: Stack(
        children: [
          Column(
            children: [
              // Top pane: its header extends up behind the status bar.
              Expanded(child: _splitPane(cfg.topTab, topInset: topInset)),
              separator,
              Expanded(child: _splitPane(cfg.bottomTab, topInset: 0)),
              _buildSplitTabBar(cfg, hideLabels),
            ],
          ),
          // Reconfigure drop region (resolves top/bottom half during a header
          // drag). Covers the panes but not the tab bar.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: barHeight,
            child: _SplitDropRegion(
              regionKey: _splitRegionKey,
              onMove: _setSplitPreview,
              onLeave: _onSplitDragLeave,
              onAccept: _commitSplitPreview,
            ),
          ),
          if (_splitDragging && _splitPreview != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: barHeight,
              child: IgnorePointer(
                child: _SplitPreview(
                  config: _splitPreview!,
                  topName: _tabName(_splitPreview!.topTab),
                  bottomName: _tabName(_splitPreview!.bottomTab),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: barHeight,
            child: UndoBanner(controller: _undoController),
          ),
        ],
      ),
    );
  }

  /// Bottom bar for split mode. Reuses the real [CupertinoTabBar] (so it's
  /// pixel-identical to the normal bar) and forces both split tabs to render
  /// their accent "active" icon so they read as selected. Falls back to a
  /// minimal bar when the current page somehow holds fewer than two tabs
  /// (CupertinoTabBar requires ≥2 items).
  Widget _buildSplitTabBar(_SplitConfig cfg, bool hideLabels) {
    final items = _pageItems();
    final highlighted = {cfg.topTab, cfg.bottomTab};
    final built = <BottomNavigationBarItem>[];
    var current = 0;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final base = _renderTabItem(context, it, hideLabels, false);
      final isHi =
          it.kind == TabKind.builtin && highlighted.contains(it.builtinIndex);
      if (isHi) {
        // Force the accent (active) icon regardless of CupertinoTabBar's single
        // currentIndex so BOTH split tabs look selected.
        built.add(BottomNavigationBarItem(
          icon: base.activeIcon,
          activeIcon: base.activeIcon,
          label: base.label,
        ));
        if (it.builtinIndex == cfg.topTab) current = i;
      } else {
        built.add(base);
      }
    }
    if (items.length < 2) {
      return _SplitTabBar(
        items: built,
        builtinIndices: [
          for (final it in items)
            it.kind == TabKind.builtin ? (it.builtinIndex ?? -1) : -1
        ],
        highlighted: highlighted,
        onTap: _onSplitTabBarTap,
      );
    }
    return CupertinoTabBar(
      currentIndex: current.clamp(0, items.length - 1),
      activeColor: CupertinoColors.label,
      inactiveColor: CupertinoColors.secondaryLabel,
      backgroundColor: const CupertinoDynamicColor.withBrightness(
        color: Color(0xF0F9F9F9),
        darkColor: Color(0xF01D1D1D),
      ),
      onTap: _onSplitTabBarTap,
      items: built,
    );
  }

  /// One subwindow: a draggable header (long-press to reconfigure placement,
  /// tap ✕ to close) atop the tab's live content. [topInset] reserves room for
  /// the status bar (top pane only); the inner view's own top/bottom safe-area
  /// padding is stripped so its nav bar sits flush under the header.
  Widget _splitPane(int tab, {required double topInset}) {
    final payload =
        _TabDragPayload(draggedTab: tab, hostTab: _otherSplitTab(tab));
    return Column(
      children: [
        LongPressDraggable<_TabDragPayload>(
          data: payload,
          feedback: _SplitTabDragFeedback(label: _tabName(tab)),
          onDragStarted: () => setState(() => _splitDragging = true),
          onDragEnd: (d) => _onSplitDragEnd(payload, d.wasAccepted),
          child: _SplitPaneHeader(
            title: _tabName(tab),
            topInset: topInset,
            onClose: () => _closeSplitWindow(tab),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: CupertinoTabView(
              navigatorKey: _navigatorKeys[tab],
              navigatorObservers: [_depthObservers[tab]],
              builder: (ctx) => _tabContent(ctx, tab),
            ),
          ),
        ),
      ],
    );
  }

  void _onSplitTabBarTap(int visualIndex) {
    final items = _pageItems();
    if (visualIndex < 0 || visualIndex >= items.length) return;
    final item = items[visualIndex];
    if (item.kind == TabKind.builtin && item.builtinIndex != null) {
      final b = item.builtinIndex!;
      final cfg = _splitConfig;
      // Tapping a tab that's already part of the split keeps the split as-is.
      if (cfg != null && (cfg.topTab == b || cfg.bottomTab == b)) return;
      _exitSplitTo(b);
      return;
    }
    // Shortcut: leave split, then route the shortcut normally.
    _exitSplitTo(_lastTabIndex);
    _handleTabTap(visualIndex);
  }

  /// Whether the tab bar's horizontal swipe moves between Spaces instead of
  /// pages of tabs. The two modes are mutually exclusive by design — one
  /// gesture, one meaning.
  bool get _swipesSpaces =>
      widget.settingsController.tabBarSwipeMode == TabBarSwipeMode.spaces;

  /// Switches to the previous / next Space. The whole app re-keys on the
  /// active space id (see main.dart), so this shell — and every navigator in
  /// it — is rebuilt from scratch; nothing after the call may touch state.
  bool _switchingSpace = false;

  /// Horizontal distance the current space-swipe has covered, in pixels.
  /// Accumulated across drag updates so the release can tell a deliberate pull
  /// from a stray twitch.
  double _spaceDragOffset = 0;

  Future<void> _switchSpace(int delta) async {
    // switchSpace tears down and rebuilds every per-space controller; a second
    // swipe landing mid-switch would run that twice over the same state.
    if (_switchingSpace) return;
    final manager = SpaceManagerProvider.maybeOf(context);
    final transition = SpaceSwitchTransition.maybeOf(context);
    if (manager == null) {
      transition?.cancelDrag();
      return;
    }
    final spaces = manager.spaces;
    if (spaces.length < 2) {
      transition?.cancelDrag();
      return;
    }
    final current = spaces.indexWhere((sp) => sp.id == manager.activeSpaceId);
    if (current < 0) {
      transition?.cancelDrag();
      return;
    }
    final next = (current + delta).clamp(0, spaces.length - 1);
    if (next == current) {
      // Already at the first or last space — let the drag fall back rather
      // than leaving the screen parked off-centre.
      transition?.cancelDrag();
      return;
    }
    _switchingSpace = true;
    Future<void> apply() async {
      try {
        // Remember the tab so the next space opens on the same one — both for
        // this switch and for the "last opened tab" launch preference.
        _tabAcrossSpaceSwitch = _lastTabIndex;
        await widget.settingsController.setLastOpenedTab(_lastTabIndex);
        await manager.switchSpace(spaces[next].id);
      } finally {
        _switchingSpace = false;
      }
    }

    if (transition == null) {
      await apply();
      return;
    }
    await transition.run(direction: delta, switchSpace: apply);
  }

  void _switchPage(int delta) {
    // Navigate only between non-empty pages so swiping can never land on an
    // empty page — empty pages are simply skipped over.
    final navigable = _navigablePageIndices();
    if (navigable.length <= 1) return;
    var pos = navigable.indexOf(_currentPage);
    if (pos < 0) pos = 0; // current page emptied out — start from the first.
    final nextPos = (pos + delta).clamp(0, navigable.length - 1);
    final next = navigable[nextPos];
    if (next == _currentPage) return;
    setState(() => _currentPage = next);
    // Recompute initial visible tab so _tabController points to a valid index
    // on the new page.
    final visible = _computeVisibleIndices();
    if (!visible.contains(_lastTabIndex)) {
      _lastTabIndex = visible.first;
    }
    _tabController.index = _visualForBuiltin(_lastTabIndex);
    // Page swiping doesn't go through the tab-bar tap handler, so refresh the
    // floating + button for whichever tab the new page lands on.
    _refreshPlusForTab(_lastTabIndex);
  }
}

/// A minimal bottom bar showing a single tab, used when the current page has
/// only one tab but other pages exist (CupertinoTabBar requires ≥2 items).
/// Mirrors CupertinoTabBar's look so it's indistinguishable from the real bar.
class _SingleTabBar extends StatelessWidget {
  const _SingleTabBar({
    required this.item,
    required this.color,
    required this.onTap,
  });

  final BottomNavigationBarItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const bg = CupertinoDynamicColor.withBrightness(
      color: Color(0xF0F9F9F9),
      darkColor: Color(0xF01D1D1D),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50 + bottom,
        padding: EdgeInsets.only(bottom: bottom),
        decoration: BoxDecoration(
          color: bg.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.0,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 30),
                child: item.activeIcon,
              ),
              if (item.label != null)
                Text(
                  item.label!,
                  style: TextStyle(fontSize: 10, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny page indicator (○ ● ○ …) shown above the tab bar.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 7 : 5,
            height: i == current ? 7 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? CupertinoColors.label.resolveFrom(context)
                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
      ],
    );
  }
}

/// iPad layout: persistent left sidebar with the same tab items, content on
/// the right wrapped in IndexedStack so each tab keeps its scroll/nav state
/// while inactive.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.visibleIndices,
    required this.hideLabels,
    required this.lastTabIndex,
    required this.showSelection,
    required this.navigatorKeys,
    required this.depthObservers,
    required this.tabItem,
    required this.tabContent,
    required this.onTap,
  });

  final List<int> visibleIndices;
  final bool hideLabels;
  final int lastTabIndex;
  final bool showSelection;
  final List<GlobalKey<NavigatorState>> navigatorKeys;
  final List<NavigatorObserver> depthObservers;
  final BottomNavigationBarItem Function(BuildContext, int) tabItem;
  final Widget Function(BuildContext, int) tabContent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final activeVisualIdx = visibleIndices.indexOf(lastTabIndex);
    final safeActive = activeVisualIdx < 0 ? 0 : activeVisualIdx;
    return Row(
      children: [
        // Sidebar — fixed-width column with the same icons used in the tab
        // bar. Keeping the same _tabItem helper means a single source of truth
        // for the icon set across both layouts.
        Container(
          width: hideLabels ? 72 : 200,
          decoration: BoxDecoration(
            color: const CupertinoDynamicColor.withBrightness(
              color: Color(0xF0F4F4F4),
              darkColor: Color(0xF01A1A1A),
            ).resolveFrom(context),
            border: Border(
              right: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  for (int i = 0; i < visibleIndices.length; i++)
                    _SidebarTile(
                      item: tabItem(context, visibleIndices[i]),
                      selected: showSelection && i == safeActive,
                      hideLabel: hideLabels,
                      onTap: () => onTap(visibleIndices[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: safeActive,
            children: [
              for (final logicalIdx in visibleIndices)
                CupertinoTabView(
                  navigatorKey: navigatorKeys[logicalIdx],
                  navigatorObservers: [depthObservers[logicalIdx]],
                  builder: (ctx) => tabContent(ctx, logicalIdx),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.hideLabel,
    required this.onTap,
  });

  final BottomNavigationBarItem item;
  final bool selected;
  final bool hideLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label ?? '',
      button: true,
      selected: selected,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withOpacity(0.15)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: selected ? item.activeIcon : item.icon,
                ),
              ),
              if (!hideLabel && item.label != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.accent
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Tracks push/pop depth and optionally counts routes with a specific name.
class _DepthObserver extends NavigatorObserver {
  _DepthObserver({required this.onChanged, this.trackedRouteName});

  final void Function(int depth, int trackedCount) onChanged;
  final String? trackedRouteName;
  int depth = 1;
  int trackedCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return; // skip the navigator's own initial route
    depth++;
    if (trackedRouteName != null && route.settings.name == trackedRouteName) {
      trackedCount++;
    }
    onChanged(depth, trackedCount);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth--;
    if (trackedRouteName != null && route.settings.name == trackedRouteName) {
      trackedCount--;
    }
    onChanged(depth, trackedCount);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth--;
    if (trackedRouteName != null && route.settings.name == trackedRouteName) {
      trackedCount--;
    }
    onChanged(depth, trackedCount);
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({
    required this.onPressed,
    this.enabled = true,
    this.scale = 1.0,
  });

  final VoidCallback onPressed;
  // When false, render the button greyed and don't fire onPressed. Dragging
  // is also disabled — there's nothing to drop onto if there's no list to
  // create a task in.
  final bool enabled;

  // Multiplier on the stock 52 px button (1.0 = stock). Drives both the circle
  // and the icon so the lifted drag feedback scales with it too.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final dimension = 52.0 * scale;
    final visual = Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.accent
            : CupertinoColors.systemGrey3.resolveFrom(context),
        shape: BoxShape.circle,
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        CupertinoIcons.plus,
        color: CupertinoColors.white,
        size: 24 * scale,
      ),
    );
    if (!enabled) {
      return Semantics(
        label: S.of(context).add,
        button: true,
        enabled: false,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: null,
          child: visual,
        ),
      );
    }
    return Semantics(
      label: S.of(context).add,
      button: true,
      child: Draggable<PlusDragPayload>(
        data: const PlusDragPayload(),
        feedback: visual,
        childWhenDragging: Opacity(opacity: 0.3, child: visual),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: visual,
        ),
      ),
    );
  }
}

// ── Split Screen support types & widgets ─────────────────────────────────────

/// A committed (or previewed) split arrangement: which logical tab renders on
/// top and which on the bottom. [draggedTab] (preview only) is the window shown
/// ghosted while the user is still dragging.
class _SplitConfig {
  const _SplitConfig({
    required this.topTab,
    required this.bottomTab,
    this.draggedTab,
  });

  final int topTab;
  final int bottomTab;
  final int? draggedTab;

  @override
  bool operator ==(Object other) =>
      other is _SplitConfig &&
      other.topTab == topTab &&
      other.bottomTab == bottomTab &&
      other.draggedTab == draggedTab;

  @override
  int get hashCode => Object.hash(topTab, bottomTab, draggedTab);
}

/// Payload carried while dragging a tab-bar button or a subwindow header.
class _TabDragPayload {
  const _TabDragPayload({required this.draggedTab, required this.hostTab});

  /// The tab being moved (the window that follows the finger / gets ghosted).
  final int draggedTab;

  /// The tab it pairs with (the other window).
  final int hostTab;
}

/// Geometry for the partner tab's slot in the bottom bar, used to position the
/// invisible drag handle that enters split mode.
class _PartnerSlot {
  const _PartnerSlot({
    required this.partnerTab,
    required this.hostTab,
    required this.visualIndex,
    required this.itemCount,
  });

  final int partnerTab;
  final int hostTab;
  final int visualIndex;
  final int itemCount;
}

/// Translucent drop region over the content. Resolves a hovering tab-drag to
/// the top or bottom half (driving the preview) and commits on release.
class _SplitDropRegion extends StatelessWidget {
  const _SplitDropRegion({
    required this.regionKey,
    required this.onMove,
    required this.onLeave,
    required this.onAccept,
  });

  final GlobalKey regionKey;
  final void Function(_TabDragPayload payload, bool topHalf) onMove;
  final VoidCallback onLeave;
  final void Function(_TabDragPayload payload) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_TabDragPayload>(
      builder: (_, __, ___) => SizedBox.expand(key: regionKey),
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        final box = regionKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        onMove(details.data, local.dy < box.size.height / 2);
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data),
    );
  }
}

/// Pill shown under the finger while dragging a tab button / window header.
class _SplitTabDragFeedback extends StatelessWidget {
  const _SplitTabDragFeedback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-24, -44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.rectangle_grid_1x2,
                size: 16, color: CupertinoColors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The thin header strip atop each subwindow. Long-pressing it (handled by the
/// enclosing draggable) re-enters placement configuration; the ✕ closes the
/// window.
class _SplitPaneHeader extends StatelessWidget {
  const _SplitPaneHeader({
    required this.title,
    required this.onClose,
    this.topInset = 0,
  });

  final String title;
  final VoidCallback onClose;

  /// Extra padding above the header row, used by the top pane so the header's
  /// background fills behind the status bar.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 2, top: topInset),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.rectangle_grid_1x2,
              size: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Icon(
              CupertinoIcons.line_horizontal_3,
              size: 15,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            Semantics(
              label: S.of(context).closeWindow,
              button: true,
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                onPressed: onClose,
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom bottom bar for split mode that highlights every tab in [highlighted]
/// (so both split windows read as "selected").
class _SplitTabBar extends StatelessWidget {
  const _SplitTabBar({
    required this.items,
    required this.builtinIndices,
    required this.highlighted,
    required this.onTap,
  });

  final List<BottomNavigationBarItem> items;
  final List<int> builtinIndices;
  final Set<int> highlighted;
  final void Function(int visualIndex) onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const bg = CupertinoDynamicColor.withBrightness(
      color: Color(0xF0F9F9F9),
      darkColor: Color(0xF01D1D1D),
    );
    final active = CupertinoColors.label.resolveFrom(context);
    final inactive = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      height: 50 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: bg.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.0,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: _cell(
                  context,
                  items[i],
                  highlighted.contains(builtinIndices[i]),
                  active,
                  inactive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, BottomNavigationBarItem item,
      bool isActive, Color active, Color inactive) {
    final color = isActive ? active : inactive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTheme(
          data: IconThemeData(color: color, size: 28),
          child: isActive ? item.activeIcon : item.icon,
        ),
        if (item.label != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(item.label!, style: TextStyle(fontSize: 10, color: color)),
          ),
      ],
    );
  }
}

/// Ghosted preview of the proposed split arrangement shown while dragging.
class _SplitPreview extends StatelessWidget {
  const _SplitPreview({
    required this.config,
    required this.topName,
    required this.bottomName,
  });

  final _SplitConfig config;
  final String topName;
  final String bottomName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _pane(
            context,
            topName,
            ghosted: config.draggedTab == config.topTab,
          ),
        ),
        Expanded(
          child: _pane(
            context,
            bottomName,
            ghosted: config.draggedTab == config.bottomTab,
          ),
        ),
      ],
    );
  }

  Widget _pane(BuildContext context, String name, {required bool ghosted}) {
    final pane = Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.rectangle_grid_1x2,
                size: 22, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
    return Opacity(opacity: ghosted ? 0.45 : 0.95, child: pane);
  }
}
