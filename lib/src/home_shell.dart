import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'folders/folder_controller.dart';
import 'notes/note_controller.dart';
import 'notes/notes_view.dart';
import 'routines/routine_controller.dart';
import 'routines/routine_creation_view.dart';
import 'routines/routines_view.dart';
import 'settings/backup_service.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';
import 'tasks/task_controller.dart';
import 'tasks/task_creation_sheet.dart';
import 'tasks/tasks_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settingsController,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.backupService,
  });

  static const routeName = '/';

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final BackupService backupService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CupertinoTabController _tabController;
  // 5 tabs: Tasks(0) Notes(1) Calendar(2) Routines(3) Settings(4)
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  late final List<_DepthObserver> _depthObservers;
  final _activeListId = ValueNotifier<String?>(null);
  final _activeDueDate = ValueNotifier<DateTime?>(null);
  final _calendarResetSignal = ValueNotifier<int>(0);
  final _showPlusButton = ValueNotifier<bool>(true);
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
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
    _tabController.dispose();
    _activeListId.dispose();
    _activeDueDate.dispose();
    _calendarResetSignal.dispose();
    _showPlusButton.dispose();
    super.dispose();
  }

  void _onPlusPressed() {
    if (_lastTabIndex == 3) {
      _navigatorKeys[3].currentState?.push(
        CupertinoPageRoute(
          settings: const RouteSettings(name: 'routine_creation'),
          builder: (_) => RoutineCreationView(
            controller: widget.routineController,
          ),
        ),
      );
    } else {
      showTaskCreationSheet(
        context,
        widget.taskController,
        widget.folderController,
        initialListId: _activeListId.value,
        initialDueDate: _activeDueDate.value,
      );
    }
  }

  void _onTabTapped(int tappedIndex) {
    if (tappedIndex == _lastTabIndex) {
      _navigatorKeys[tappedIndex].currentState
          ?.popUntil((route) => route.isFirst);
      if (tappedIndex == 2) {
        _calendarResetSignal.value++;
      }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoTabScaffold(
          controller: _tabController,
          tabBar: CupertinoTabBar(
            activeColor: const Color(0xFF000000),
            inactiveColor: const Color(0xFF636366),
            backgroundColor: const CupertinoDynamicColor.withBrightness(
              color: Color(0xF0F9F9F9),
              darkColor: Color(0xF01D1D1D),
            ),
            onTap: _onTabTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                      AssetImage('assets/icons/tab_bar/tasks.png')),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                    AssetImage('assets/icons/tab_bar/tasks.png'),
                    color: Color(0xFFFF4D00),
                  ),
                ),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                      AssetImage('assets/icons/tab_bar/notes.png')),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                    AssetImage('assets/icons/tab_bar/notes.png'),
                    color: Color(0xFFFF4D00),
                  ),
                ),
                label: 'Notes',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                      AssetImage('assets/icons/tab_bar/calendar.png')),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                    AssetImage('assets/icons/tab_bar/calendar.png'),
                    color: Color(0xFFFF4D00),
                  ),
                ),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                      AssetImage('assets/icons/tab_bar/routines.png')),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ImageIcon(
                    AssetImage('assets/icons/tab_bar/routines.png'),
                    color: Color(0xFFFF4D00),
                  ),
                ),
                label: 'Routines',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(CupertinoIcons.gear_alt, size: 24),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    CupertinoIcons.gear_alt_fill,
                    size: 24,
                    color: Color(0xFFFF4D00),
                  ),
                ),
                label: 'Settings',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[index],
              navigatorObservers: [_depthObservers[index]],
              builder: (context) => switch (index) {
                0 => TasksView(
                    controller: widget.taskController,
                    folderController: widget.folderController,
                    activeListId: _activeListId,
                    activeDueDate: _activeDueDate,
                  ),
                1 => NotesView(controller: widget.noteController),
                2 => CalendarView(
                    controller: widget.taskController,
                    folderController: widget.folderController,
                    resetSignal: _calendarResetSignal,
                  ),
                3 => RoutinesView(controller: widget.routineController),
                _ => SettingsView(
                    controller: widget.settingsController,
                    backupService: widget.backupService,
                  ),
              },
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
        decoration: const BoxDecoration(
          color: Color(0xFFFF4D00),
          shape: BoxShape.circle,
          boxShadow: [
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
