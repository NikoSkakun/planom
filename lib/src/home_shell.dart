import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'localization/strings.dart';
import 'calendar/event_controller.dart';
import 'calendar/event_creation_sheet.dart';
import 'folders/folder_controller.dart';
import 'notes/note_controller.dart';
import 'notes/notes_view.dart';
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
import 'utils/selection_menu.dart';

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
  });

  static const routeName = '/';

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final BackupService backupService;
  final SecurityService? securityService;

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
  int _lastTabIndex = 0;
  late CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
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
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final visibleIndices = _computeVisibleIndices();
    if (!visibleIndices.contains(_lastTabIndex)) {
      _lastTabIndex = 0;
      _tabController.index = 0;
      _showPlusButton.value = _depthObservers[0].trackedCount == 0;
    } else {
      _tabController.index = visibleIndices.indexOf(_lastTabIndex);
    }
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
  }

  List<int> _computeVisibleIndices() {
    final sc = widget.settingsController;
    final ordered = sc.tabOrder.where((i) => sc.isTabVisible(i)).toList();
    return ordered.isEmpty ? [0] : ordered;
  }

  BottomNavigationBarItem _tabItem(
      BuildContext context, int logicalIdx, bool hideLabels) {
    final s = S.of(context);
    switch (logicalIdx) {
      case 0:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(AssetImage('assets/icons/tab_bar/tasks.png')),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(
              AssetImage('assets/icons/tab_bar/tasks.png'),
              color: AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabTasks,
        );
      case 1:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(AssetImage('assets/icons/tab_bar/notes.png')),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(
              AssetImage('assets/icons/tab_bar/notes.png'),
              color: AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabNotes,
        );
      case 2:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child:
                ImageIcon(AssetImage('assets/icons/tab_bar/calendar.png')),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(
              AssetImage('assets/icons/tab_bar/calendar.png'),
              color: AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabCalendar,
        );
      case 3:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child:
                ImageIcon(AssetImage('assets/icons/tab_bar/routines.png')),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(top: 8),
            child: ImageIcon(
              AssetImage('assets/icons/tab_bar/routines.png'),
              color: AppColors.accent,
            ),
          ),
          label: hideLabels ? null : s.tabRoutines,
        );
      default:
        return BottomNavigationBarItem(
          icon: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(CupertinoIcons.gear_alt, size: 24),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(
              CupertinoIcons.gear_alt_fill,
              size: 24,
              color: AppColors.accent,
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
        ),
      1 => NotesView(
          controller: widget.noteController,
          collapseSignal: _notesCollapseSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
        ),
      2 => CalendarView(
          controller: widget.taskController,
          folderController: widget.folderController,
          eventController: widget.eventController,
          resetSignal: _calendarResetSignal,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
          onDaySelected: (d) => _activeDueDate.value = d,
        ),
      3 => RoutinesView(
          controller: widget.routineController,
          settingsController: widget.settingsController,
          backupService: widget.backupService,
        ),
      _ => SettingsView(
          controller: widget.settingsController,
          backupService: widget.backupService,
          securityService: widget.securityService,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) {
        final hideLabels = widget.settingsController.hideTabLabels;
        final visibleIndices = _computeVisibleIndices();

        return Stack(
          children: [
            CupertinoTabScaffold(
              controller: _tabController,
              tabBar: CupertinoTabBar(
                activeColor: CupertinoColors.label,
                inactiveColor: CupertinoColors.secondaryLabel,
                backgroundColor: const CupertinoDynamicColor.withBrightness(
                  color: Color(0xF0F9F9F9),
                  darkColor: Color(0xF01D1D1D),
                ),
                onTap: (visualIdx) =>
                    _onTabTapped(visibleIndices[visualIdx]),
                items: visibleIndices
                    .map((i) => _tabItem(context, i, hideLabels))
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
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _showPlusButton,
              builder: (context, show, child) => show
                  ? Positioned(
                      right: 20,
                      bottom: 50 + MediaQuery.paddingOf(context).bottom + 12,
                      child: _PlusButton(onPressed: _onPlusPressed),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
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
    return CupertinoButton(
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
    );
  }
}
