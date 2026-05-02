import 'package:flutter/cupertino.dart';

import 'calendar/calendar_view.dart';
import 'folders/folder_controller.dart';
import 'routines/routines_view.dart';
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
  });

  static const routeName = '/';

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CupertinoTabController _tabController;
  final _navigatorKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());
  final _activeListId = ValueNotifier<String?>(null);
  final _activeDueDate = ValueNotifier<DateTime?>(null);
  final _calendarResetSignal = ValueNotifier<int>(0);
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeListId.dispose();
    _activeDueDate.dispose();
    _calendarResetSignal.dispose();
    super.dispose();
  }

  void _onTabTapped(int tappedIndex) {
    if (tappedIndex == _lastTabIndex) {
      // Same tab tapped — pop to root of that tab's navigator.
      _navigatorKeys[tappedIndex].currentState
          ?.popUntil((route) => route.isFirst);
      if (tappedIndex == 1) {
        _calendarResetSignal.value++;
      }
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
            onTap: _onTabTapped,
            items: const [
              BottomNavigationBarItem(
                icon: ImageIcon(AssetImage('assets/icons/tab_bar/tasks.png')),
                activeIcon: ImageIcon(
                  AssetImage('assets/icons/tab_bar/tasks.png'),
                  color: Color(0xFFFF4D00),
                ),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: ImageIcon(
                    AssetImage('assets/icons/tab_bar/calendar.png')),
                activeIcon: ImageIcon(
                  AssetImage('assets/icons/tab_bar/calendar.png'),
                  color: Color(0xFFFF4D00),
                ),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: ImageIcon(
                    AssetImage('assets/icons/tab_bar/routines.png')),
                activeIcon: ImageIcon(
                  AssetImage('assets/icons/tab_bar/routines.png'),
                  color: Color(0xFFFF4D00),
                ),
                label: 'Routines',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[index],
              routes: {
                SettingsView.routeName: (_) =>
                    SettingsView(controller: widget.settingsController),
              },
              builder: (context) => switch (index) {
                0 => TasksView(
                    controller: widget.taskController,
                    folderController: widget.folderController,
                    activeListId: _activeListId,
                    activeDueDate: _activeDueDate,
                  ),
                1 => CalendarView(
                    controller: widget.taskController,
                    resetSignal: _calendarResetSignal,
                  ),
                _ => const RoutinesView(),
              },
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 50 + MediaQuery.paddingOf(context).bottom + 12,
          child: _PlusButton(
            onPressed: () => showTaskCreationSheet(
              context,
              widget.taskController,
              widget.folderController,
              initialListId: _activeListId.value,
              initialDueDate: _activeDueDate.value,
            ),
          ),
        ),
      ],
    );
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
