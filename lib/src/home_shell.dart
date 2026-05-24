import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'localization/strings.dart';
import 'calendar/event_controller.dart';
import 'calendar/event_creation_sheet.dart';
import 'folders/folder_controller.dart';
import 'integrations/google/google_calendar_controller.dart';
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
import 'tasks/task_controller.dart';
import 'tasks/task_creation_sheet.dart';
import 'tasks/tasks_view.dart';
import 'theme/app_theme.dart';
import 'utils/fast_route.dart';
import 'utils/platform_capabilities.dart';
import 'utils/selection_menu.dart';
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
    required this.backupService,
    this.securityService,
    required this.googleCalendarController,
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
  final BackupService backupService;
  final SecurityService? securityService;
  final GoogleCalendarController googleCalendarController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Logical indices: 0=Tasks 1=Notes 2=Calendar 3=Routines 4=Settings
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  late final List<_DepthObserver> _depthObservers;
  final _activeListId = ValueNotifier<String?>(null);
  final _activeDueDate = ValueNotifier<DateTime?>(null);
  final _tasksCollapseSignal = ValueNotifier<int>(0);
  final _notesCollapseSignal = ValueNotifier<int>(0);
  final _calendarResetSignal = ValueNotifier<int>(0);
  final _showPlusButton = ValueNotifier<bool>(true);
  final _undoController = UndoController();
  // True while the user is viewing Settings via the global overlay (i.e. the
  // Settings tab is hidden but they opened Settings from another tab's ⋯
  // menu). The tab bar repaints all tabs as inactive while this is true.
  final ValueNotifier<bool> _globalSettingsOpen = ValueNotifier<bool>(false);
  Route<void>? _globalSettingsRoute;
  int _lastTabIndex = 0;
  late CupertinoTabController _tabController;

  void _openGlobalSettings() {
    if (_globalSettingsOpen.value) return;
    final route = FastRoute<void>(
      builder: (_) => SettingsView(
        controller: widget.settingsController,
        backupService: widget.backupService,
        securityService: widget.securityService,
        googleCalendarController: widget.googleCalendarController,
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
    final initialVisual = visible.indexOf(_lastTabIndex);
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
      // Calendar tab: hide when navigated deeper.
      _DepthObserver(
        onChanged: (depth, trackedCount) {
          if (_lastTabIndex == 2) _showPlusButton.value = depth <= 1;
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
    // Notes (1) and Settings (4) never show the global +.
    _showPlusButton.value = _lastTabIndex != 1 && _lastTabIndex != 4;
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_onSettingsChanged);
    _tabController.dispose();
    _activeListId.dispose();
    _activeDueDate.dispose();
    _tasksCollapseSignal.dispose();
    _notesCollapseSignal.dispose();
    _calendarResetSignal.dispose();
    _showPlusButton.dispose();
    _globalSettingsOpen.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
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
      _tabController.index = visibleIndices.indexOf(4);
      _showPlusButton.value = false;
      return;
    }

    if (visibleIndices.contains(_lastTabIndex)) {
      _tabController.index = visibleIndices.indexOf(_lastTabIndex);
      return;
    }
    // The active tab was just hidden from the tab bar. Fall back to Tasks (or
    // the first remaining tab) so the scaffold index stays valid.
    final wasSettings = _lastTabIndex == 4;
    final fallback = visibleIndices.contains(0) ? 0 : visibleIndices.first;
    _lastTabIndex = fallback;
    _tabController.index = visibleIndices.indexOf(fallback);
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

    // On Calendar tab with a selected day: choose Task vs Event.
    if (_lastTabIndex == 2 && _activeDueDate.value != null) {
      _showCalendarItemPicker(_activeDueDate.value!);
      return;
    }

    showTaskCreationSheet(
      context,
      widget.taskController,
      widget.folderController,
      initialListId: _activeListId.value,
      initialDueDate: _activeDueDate.value,
    );
  }

  Future<void> _showCalendarItemPicker(DateTime date) async {
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
      );
    } else if (choice == 'event') {
      showEventCreationSheet(
        context,
        widget.eventController,
        initialDate: date,
        googleCalendarController: widget.googleCalendarController,
      );
    }
  }

  void _onTabTapped(int tappedIndex) {
    if (tappedIndex == _lastTabIndex) {
      _navigatorKeys[tappedIndex].currentState
          ?.popUntil((route) => route.isFirst);
      if (tappedIndex == 0) _tasksCollapseSignal.value++;
      if (tappedIndex == 1) _notesCollapseSignal.value++;
      if (tappedIndex == 2) _calendarResetSignal.value++;
    }
    switch (tappedIndex) {
      case 0:
        _showPlusButton.value = _depthObservers[0].trackedCount == 0;
      case 1:
        _showPlusButton.value = false;
      case 4:
        _showPlusButton.value = false;
      default:
        _showPlusButton.value = _depthObservers[tappedIndex].depth <= 1;
    }
    _lastTabIndex = tappedIndex;
    widget.settingsController.setLastOpenedTab(tappedIndex);
  }

  List<int> _computeVisibleIndices() {
    final sc = widget.settingsController;
    final ordered = sc.tabOrder.where((i) => sc.isTabVisible(i)).toList();
    return ordered.isEmpty ? [0] : ordered;
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
            child: Icon(CupertinoIcons.gear_alt, size: 24),
          ),
          activeIcon: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              deselectAll
                  ? CupertinoIcons.gear_alt
                  : CupertinoIcons.gear_alt_fill,
              size: 24,
              color: deselectAll ? null : AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabSettings,
        );
    }
  }

  Widget _tabContent(BuildContext context, int logicalIdx) {
    return switch (logicalIdx) {
      0 => TasksView(
          controller: widget.taskController,
          folderController: widget.folderController,
          settingsController: widget.settingsController,
          activeListId: _activeListId,
          activeDueDate: _activeDueDate,
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
          resetSignal: _calendarResetSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
          onDaySelected: (d) => _activeDueDate.value = d,
          db: SpaceManagerProvider.of(context).db,
          noteController: widget.noteController,
          googleCalendarController: widget.googleCalendarController,
        ),
      3 => RoutinesView(
          controller: widget.routineController,
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
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return UndoScope(
      controller: _undoController,
      child: _buildShell(context),
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
            else if (visibleIndices.length <= 1)
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
                      onTap: (visualIdx) =>
                          _onTabTapped(visibleIndices[visualIdx]),
                      items: visibleIndices
                          .map((i) =>
                              _tabItem(context, i, hideLabels, overlayOpen))
                          .toList(),
                    ),
                    tabBuilder: (context, visualIdx) {
                      final logicalIdx = visibleIndices[visualIdx];
                      return CupertinoTabView(
                        navigatorKey: _navigatorKeys[logicalIdx],
                        navigatorObservers: [_depthObservers[logicalIdx]],
                        builder: (ctx) => _tabContent(ctx, logicalIdx),
                      );
                    },
                  );
                },
              ),
            ValueListenableBuilder<bool>(
              valueListenable: _showPlusButton,
              builder: (context, show, child) => show
                  ? Positioned(
                      right: 20,
                      bottom: isWide
                          ? 24
                          : visibleIndices.length <= 1
                              ? MediaQuery.paddingOf(context).bottom + 16
                              : 50 +
                                  MediaQuery.paddingOf(context).bottom +
                                  12,
                      child: _PlusButton(onPressed: _onPlusPressed),
                    )
                  : const SizedBox.shrink(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: isWide
                  ? 0
                  : visibleIndices.length <= 1
                      ? MediaQuery.paddingOf(context).bottom
                      : 50 + MediaQuery.paddingOf(context).bottom,
              child: UndoBanner(controller: _undoController),
            ),
          ],
        );
      },
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
  const _PlusButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context).add,
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.plus,
            color: CupertinoColors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
