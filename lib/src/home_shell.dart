import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'localization/strings.dart';
import 'calendar/event_controller.dart';
import 'calendar/event_creation_sheet.dart';
import 'contacts/contact_controller.dart';
import 'contacts/contact_creation_sheet.dart';
import 'folders/create_folder_list_sheet.dart';
import 'folders/folder_controller.dart';
import 'integrations/apple/device_calendar_controller.dart';
import 'integrations/google/google_calendar_controller.dart';
import 'models/list_type.dart';
import 'notes/create_note_folder_sheet.dart';
import 'notes/note_controller.dart';
import 'notes/notes_view.dart';
import 'spaces/space_manager.dart';
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
import 'tasks/task_controller.dart';
import 'tasks/task_creation_sheet.dart';
import 'tasks/tasks_view.dart';
import 'theme/app_theme.dart';
import 'utils/fast_route.dart';
import 'utils/platform_capabilities.dart';
import 'utils/plus_button_inset_scope.dart';
import 'utils/plus_drag_controller.dart';
import 'utils/plus_drag_payload.dart';
import 'utils/selection_menu.dart';
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

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final ContactController contactController;
  final BackupService backupService;
  final SecurityService? securityService;
  final GoogleCalendarController googleCalendarController;
  final DeviceCalendarController deviceCalendarController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Logical indices: 0=Tasks 1=Notes 2=Calendar 3=Routines 4=Settings
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
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
  final _showPlusButton = ValueNotifier<bool>(true);
  final _plusButtonInset = ValueNotifier<double>(0);
  final _undoController = UndoController();
  final _plusDragController = PlusDragController();
  // True while the user is viewing Settings via the global overlay (i.e. the
  // Settings tab is hidden but they opened Settings from another tab's ⋯
  // menu). The tab bar repaints all tabs as inactive while this is true.
  final ValueNotifier<bool> _globalSettingsOpen = ValueNotifier<bool>(false);
  Route<void>? _globalSettingsRoute;
  int _lastTabIndex = 0;
  // Which page of the multi-page tab bar is currently visible. Swiping
  // horizontally on the tab bar moves between pages.
  int _currentPage = 0;
  late CupertinoTabController _tabController;

  void _openGlobalSettings() {
    if (_globalSettingsOpen.value) return;
    final route = FastRoute<void>(
      builder: (_) => SettingsView(
        controller: widget.settingsController,
        backupService: widget.backupService,
        securityService: widget.securityService,
        googleCalendarController: widget.googleCalendarController,
        deviceCalendarController: widget.deviceCalendarController,
      ),
    );
    _globalSettingsRoute = route;
    _globalSettingsOpen.value = true;
    Navigator.of(context, rootNavigator: true).push(route).then((_) {
      if (!mounted) return;
      _globalSettingsRoute = null;
      _globalSettingsOpen.value = false;
    });
  }

  @override
  void initState() {
    super.initState();
    final visible = _computeVisibleIndices();
    _lastTabIndex = widget.settingsController.resolveInitialTab(visible);
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
    // the global overlay → silently promote the overlay to the real tab.
    if (_globalSettingsOpen.value && visibleIndices.contains(4)) {
      final route = _globalSettingsRoute;
      _globalSettingsRoute = null;
      if (route != null) {
        Navigator.of(context, rootNavigator: true).removeRoute(route);
      }
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
    switch (fallback) {
      case 0:
        _showPlusButton.value = _depthObservers[0].trackedCount == 0;
      case 1:
        _showPlusButton.value = false;
      default:
        _showPlusButton.value = _depthObservers[fallback].depth <= 1;
    }
    // Hiding the Settings tab only removes its tab-bar item — it must not yank
    // the user out of Settings. Re-open it full-screen (with the Tab Bar
    // sub-page they were on) so the screen stays put.
    if (wasSettings) _reopenSettingsFullScreen();
  }

  void _reopenSettingsFullScreen() {
    // Pushed synchronously (this runs from the visibility-toggle tap, not a
    // build) so the full-screen Settings covers the scaffold before it repaints
    // — otherwise the fallback tab would flash for a frame. The base Settings
    // page is tracked so it can be removed when the user re-enables the tab.
    final nav = Navigator.of(context, rootNavigator: true);
    final base = FastRoute<void>(
      builder: (_) => SettingsView(
        controller: widget.settingsController,
        backupService: widget.backupService,
        securityService: widget.securityService,
        googleCalendarController: widget.googleCalendarController,
        deviceCalendarController: widget.deviceCalendarController,
      ),
    );
    _globalSettingsRoute = base;
    _globalSettingsOpen.value = true;
    nav.push(base).then((_) {
      if (!mounted) return;
      _globalSettingsRoute = null;
      _globalSettingsOpen.value = false;
    });
    nav.push(
      FastRoute<void>(
        builder: (_) => TabBarSettingsView(
          controller: widget.settingsController,
        ),
      ),
    );
  }

  void _onPlusPressed() {
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
    );
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
    if (tappedIndex == _lastTabIndex) {
      _navigatorKeys[tappedIndex].currentState
          ?.popUntil((route) => route.isFirst);
      if (tappedIndex == 0) _tasksCollapseSignal.value++;
      if (tappedIndex == 1) _notesCollapseSignal.value++;
      if (tappedIndex == 2) _calendarResetSignal.value++;
      if (tappedIndex == 3) _routinesResetSignal.value++;
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
      _ => SettingsView(
          controller: widget.settingsController,
          backupService: widget.backupService,
          securityService: widget.securityService,
          googleCalendarController: widget.googleCalendarController,
          deviceCalendarController: widget.deviceCalendarController,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return UndoScope(
      controller: _undoController,
      child: PlusDragScope(
        controller: _plusDragController,
        child: PlusButtonInsetScope(
          inset: _plusButtonInset,
          child: _buildShell(context),
        ),
      ),
    );
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

        final navigablePages = _navigablePageIndices();
        // Only pages that actually hold tabs count toward the multi-page UI —
        // empty pages get no dot and can't be swiped to.
        final hasMultiplePages = navigablePages.length > 1;
        final pageItems = _pageItems();
        // The bottom tab bar disappears entirely only when there's a single
        // reachable page holding a single tab — then the app reads as one
        // screen. As soon as there's more than one non-empty page we keep a bar
        // so the user can swipe between pages, even with just one tab on a page.
        final singleNoBar =
            !isWide && pageItems.length <= 1 && !hasMultiplePages;
        // A page that holds a single tab while other non-empty pages exist.
        // CupertinoTabBar requires ≥2 items, so this case gets a bespoke
        // one-item bar instead of CupertinoTabScaffold.
        final customSingleBar =
            !isWide && hasMultiplePages && pageItems.length < 2;
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
            // Multi-page tab bar swipe overlay — covers the tab bar area and
            // detects horizontal pan to switch between (non-empty) pages.
            // Active whenever there's more than one non-empty page and we're in
            // the narrow (bottom tab bar) layout.
            if (!isWide && hasMultiplePages)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 50 + MediaQuery.paddingOf(context).bottom,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (d) {
                    final vel = d.primaryVelocity ?? 0;
                    if (vel.abs() < 200) return;
                    _switchPage(vel < 0 ? 1 : -1);
                  },
                ),
              ),
            // Page indicator dots, shown just above the tab bar when there's
            // more than one non-empty page. Empty pages get no dot.
            if (!isWide && hasMultiplePages)
              Positioned(
                left: 0,
                right: 0,
                bottom: 50 + MediaQuery.paddingOf(context).bottom + 2,
                child: IgnorePointer(
                  child: _PageDots(
                    count: navigablePages.length,
                    current: navigablePages
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
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        right: 20,
                        bottom: baseBottom + lift + undoLift,
                        child: _PlusButton(
                          onPressed: _onPlusPressed,
                          enabled: plusEnabled,
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
          ],
        );
      },
    );
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
    required this.navigatorKeys,
    required this.depthObservers,
    required this.tabItem,
    required this.tabContent,
    required this.onTap,
  });

  final List<int> visibleIndices;
  final bool hideLabels;
  final int lastTabIndex;
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
                      selected: i == safeActive,
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
  const _PlusButton({required this.onPressed, this.enabled = true});

  final VoidCallback onPressed;
  // When false, render the button greyed and don't fire onPressed. Dragging
  // is also disabled — there's nothing to drop onto if there's no list to
  // create a task in.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final visual = Container(
      width: 52,
      height: 52,
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
      child: const Icon(
        CupertinoIcons.plus,
        color: CupertinoColors.white,
        size: 24,
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
