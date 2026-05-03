# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis / lint
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter run              # Run on connected device or emulator
flutter gen-l10n         # Regenerate localization files after editing .arb files
```

Flutter binary is at `~/dev/flutter/bin/flutter` (not on PATH by default).

## Tech stack

- **Framework**: Flutter / Dart, Cupertino (iOS-native) widgets throughout — no Material widgets in UI except `showModalBottomSheet` (which requires `GlobalMaterialLocalizations.delegate` already registered)
- **Database**: `sqflite` v2, single file `planom.db`, current schema version **6**
- **State**: Flutter `ChangeNotifier` — no third-party state library
- **Routing**: `FastRoute` (custom `CupertinoPageRoute` subclass with 180 ms transition, in `lib/src/utils/fast_route.dart`) used everywhere instead of bare `CupertinoPageRoute`
- **Icons**: `cupertino_icons` package required for `CupertinoIcons`; custom PNG tab-bar icons in `assets/icons/tab_bar/`; list icons (`inbox.png`, `today.png`, `folder.png`) in `assets/icons/`; use `Image.asset` (not `ImageIcon`) when original PNG colors must be preserved
- **App badge**: `flutter_app_badger ^1.5.0` (discontinued but functional) — set by `TaskController._updateBadge()` to `todayUncompletedCount`; iOS badge permission requested in `AppDelegate.swift` via `UNUserNotificationCenter`

## Architecture

Source lives in `lib/src/` with a three-layer pattern:

- **Models** (`lib/src/models/`) — plain Dart, extend `AppItem` base class
- **Services** (`*_service.dart`) — I/O only, called only by controllers
- **Controllers** (`*_controller.dart`) — `ChangeNotifier`; own in-memory state, persist via services, call `notifyListeners()` after mutations
- **Views** (`*_view.dart`) — Cupertino widgets, subscribe via `ListenableBuilder`

### Data model hierarchy

```
AppItem (lib/src/models/item.dart)   ← base for all app records
  id: String (UUID v4)
  creationDate: DateTime
  iconId: String

Task extends AppItem (lib/src/models/task.dart)
  title: String
  note: String?
  isCompleted: bool
  dueDate: DateTime?          ← nullable; drives calendar view
  doTime: int?                ← minutes since midnight (0–1439); null = no time set
  listId: String?

Routine extends AppItem (lib/src/models/routine.dart)
  name: String
  iconColor: int              ← ARGB; iconId (from AppItem) is the SF-symbol key
  goalType: String            ← 'achieve_all' | 'certain_amount'
  goalAmount: int?            ← daily target; only for 'certain_amount'
  goalUnit: String?           ← 'ml', 'km', 'count', etc.; only for 'certain_amount'
  recordAmount: int?          ← amount added per tap; only for 'certain_amount'
  frequencyType: String       ← 'daily' | 'days_after_complete'
  weekdays: List<int>?        ← 0=Mon … 6=Sun; null = all days (daily only)
  daysAfterComplete: int?     ← gap before routine reappears (days_after_complete only)
  autoReset: String           ← 'everyday' | 'none'

RoutineEntry (lib/src/models/routine_entry.dart)   ← NOT an AppItem; no iconId
  id: String (UUID v4)
  routineId: String
  date: DateTime              ← normalized to midnight
  amount: int                 ← progress units recorded on that date
```

`Task.copyWith` accepts `clearDueDate: bool` and `clearDoTime: bool` to explicitly null out those fields (standard Dart nullable-copyWith pattern). `Routine.copyWith` follows the same clear-flag pattern for all nullable fields. Item spacing: task rows use `vertical: 7` padding; list/folder items use `vertical: 9` in custom `GestureDetector` rows (not `CupertinoListTile.notched`).

### Database (`lib/src/database/database_service.dart`)

Single `DatabaseService` class, lazy-opens `planom.db` via sqflite. Current version: **6**. Migration history: v2 adds `dueDate INTEGER`, v3 adds `listId TEXT` + folder/list tables, v4 adds `doTime INTEGER` + folder/list tables (IF NOT EXISTS guard), v5 adds `note_folders` + `notes` tables, v6 adds `routines` + `routine_entries` tables. When adding new tables/columns, bump `_dbVersion` and add an `onUpgrade` branch.

Routine DB schema:
- `routines` — stores routine definitions (all Routine fields; `weekdays` stored as comma-separated string e.g. `"0,1,2,3,4,5,6"`)
- `routine_entries` — per-day progress records; one row per (routineId, date); `amount` is cumulative for the day

### Controllers

**`TaskController`** (`lib/src/tasks/task_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → individual views
- Key API: `inboxTasks`, `inboxUncompletedCount`, `todayTasks`, `tasksForDate(DateTime)`, `addTask`, `updateTask`, `toggleCompleted`, `load`

**`RoutineController`** (`lib/src/routines/routine_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → `RoutinesView`
- Key API: `todayRoutines`, `entryForToday(routineId)`, `todayProgress(routineId)`, `isTodayCompleted(Routine)`, `recordProgress(Routine)`, `addRoutine`, `updateRoutine`, `deleteRoutine`, `load`
- `todayRoutines` filters `_routines` by schedule: `daily` checks weekday membership; `days_after_complete` shows routine when `today >= lastCompletionDate + gap`
- `recordProgress` toggles for `achieve_all` (0↔1) and increments by `recordAmount` for `certain_amount`; creates today's entry if absent
- `autoReset='none'`: carries over last known amount as today's starting value; for `achieve_all` shows as done if any historical completion exists (until toggled off today)
- Weekdays stored as `List<int>` (0=Mon … 6=Sun); Dart's `DateTime.weekday` is 1=Mon, so always subtract 1 when comparing

**`SettingsController`** (`lib/src/settings/settings_controller.dart`)
- Manages `ThemeMode`; mapped to `CupertinoThemeData.brightness` in `app.dart`

### App shell (`lib/src/home_shell.dart`)

`HomeShell` is a `StatefulWidget` that wraps a `CupertinoTabScaffold` (**4 tabs**: Tasks(0) / Notes(1) / Calendar(2) / Routines(3)) in a `Stack` with a floating orange `+` button (52×52, `Color(0xFFFF4D00)`) above the tab bar. Key state:
- `_navigatorKeys`: per-tab `GlobalKey<NavigatorState>` — used to pop-to-root on same-tab re-tap
- `_depthObservers`: per-tab `_DepthObserver extends NavigatorObserver` — tracks push/pop depth AND counts routes matching `trackedRouteName`
- `_showPlusButton`: `ValueNotifier<bool>` toggled by `_depthObservers`; passed to `ValueListenableBuilder` that wraps the `Positioned` button
- `_activeListId` / `_activeDueDate`: `ValueNotifier<T?>` that child views set to pre-fill the task creation sheet's list and date
- `_calendarResetSignal`: `ValueNotifier<int>` incremented when Calendar tab is re-tapped, causing `CalendarView` to scroll back to current month
- `_lastTabIndex`: tracks last tapped tab to detect same-tab re-tap via `CupertinoTabBar.onTap`

**Plus button visibility rules:**
- **Tab 0 (Tasks)**: shown whenever no `TaskDetailView` is on the stack — i.e. `_depthObservers[0].trackedCount == 0`. Visible on TasksView, InboxView, TodayView, FolderView, ListTaskView at any nesting depth; hidden only inside the task edit screen.
- **Tab 1 (Notes)**: always hidden — Notes manages its own UI.
- **Tabs 2 & 3 (Calendar / Routines)**: hidden when depth > 1 (any push beyond the tab root).
- `_DepthObserver` accepts an optional `trackedRouteName`; `trackedCount` increments/decrements as matching routes are pushed/popped. Tab 0's observer tracks `'task_detail'`.
- All `TaskDetailView` pushes use `RouteSettings(name: TaskDetailView.routeName)` (`'task_detail'`) so the observer can identify them.

**Plus button action (`_onPlusPressed`):**
- `_lastTabIndex == 3` (Routines): pushes `RoutineCreationView` on the Routines tab navigator via `_navigatorKeys[3]` — this increments depth to 2, hiding the button automatically.
- All other tabs: shows `TaskCreationSheet` modal (root navigator).

### Navigation

- `MyApp.onGenerateRoute` in `app.dart` handles the root `/` and `/settings` routes using `FastRoute`
- In-tab navigation (e.g. Tasks → Inbox, Inbox → TaskDetail) uses `Navigator.of(context).push(FastRoute(...))` directly
- `CupertinoTabView.routes` registers the `/settings` route inside each tab so it pushes within the tab navigator

### Tasks feature (`lib/src/tasks/`)

| File | Purpose |
|------|---------|
| `tasks_view.dart` | Tab root; shows Inbox + Today list items with icons and uncompleted count badge |
| `inbox_view.dart` | Task list; swipe-to-delete (`Dismissible`); tap row → `TaskDetailView`, tap checkbox → toggle; no dividers |
| `today_view.dart` | Smart list of tasks due **today and overdue** (dueDate ≤ today); sets `activeDueDate` so `+` button pre-fills today; overdue tasks show their date in red (`CupertinoColors.destructiveRed`) below the title |
| `task_detail_view.dart` | Edit screen; "Done" nav bar button saves via `controller.updateTask`; `routeName = 'task_detail'` used by `_DepthObserver` to hide the global `+` button |
| `task_creation_sheet.dart` | Modal bottom sheet (root navigator); title (sentence-cap) + note + date + list picker + Add; accepts `initialListId` and `initialDueDate` |
| `calendar_date_picker.dart` | Date+time picker dialog; `formatTaskDate(DateTime, {int? doTime})` and `formatDoTime(int)` helpers; returns `(DateTime?, int?)?` — outer null = barrier dismiss (no change), `(null,null)` = No Date, `(date, time?)` = selection |
| `task_controller.dart` | `ChangeNotifier` wrapping `DatabaseService`; completed tasks sink to bottom (`_completedLast`); `deleteTask`/`deleteTasksForList`; iOS badge via `flutter_app_badger` |

**TaskController ordering**: `inboxTasks`, `tasksForList`, and `todayTasks` all pass through `_completedLast()` — incomplete tasks first, completed at the bottom. Unchecking a task restores it to the incomplete group (not its original position).

**`todayTasks` / `todayUncompletedCount`**: includes all tasks where `dueDate` (normalized to midnight) is ≤ today — i.e. today's tasks plus any overdue tasks. `todayUncompletedCount` derives from `todayTasks`, so the iOS app badge automatically counts overdue uncompleted tasks.

**List/folder row items** (`_ListItem` in `tasks_view.dart`, `_FolderListItem` in `folder_view.dart`): no chevron icon — rows show icon + label + optional uncompleted count only.

### Routines feature (`lib/src/routines/`)

| File | Purpose |
|------|---------|
| `routine_icons.dart` | `kRoutineIconPresets` — 16 `(iconId, colorARGB)` preset combos; `routineIconData(iconId)` maps string keys to `CupertinoIcons` constants |
| `routine_controller.dart` | `ChangeNotifier`; owns `_routines` + `_entries` lists; computes `todayRoutines`, progress, completion state |
| `routine_creation_view.dart` | Full-screen `CupertinoPageScaffold` pushed on the Routines tab navigator; `showRoutineCreationView()` helper; also used for editing (`existing` param). Sections: name+icon row, icon picker grid, Frequency (segmented + weekday chips or days-after input + auto-reset), Goal (segmented + amount/unit/record fields) |
| `routines_view.dart` | Tab root; `todayRoutines` list with `_RoutineRow` items; swipe-to-delete (`Dismissible`); tap → `recordProgress`; long-press → edit/delete action sheet; empty state with prompt |

**Routine row layout**: 40px colored circle icon (dimmed + checkmark overlay when `achieve_all` complete) · name (strikethrough when complete) · right-aligned `_ProgressBadge` showing `"progress/goal unit"` (only for `certain_amount`)

**Icon system**: `iconId` is a string key (e.g. `'drop.fill'`, `'heart.fill'`) stored in `Routine.iconId` (inherited from `AppItem`). `iconColor` is a separate ARGB int field on `Routine`. Together they describe a filled colored circle with a white icon inside. The 16 presets in `kRoutineIconPresets` are shown as a `Wrap` grid in the creation view.

**Unit picker**: `_UnitPickerSheet` (modal bottom sheet) offers preset units (`ml`, `L`, `oz`, `count`, `minute`, `hour`, `km`, `mi`, `page`, `cup`, `lap`, `step`) plus a "Custom…" option with a free-text field.

**`autoReset` semantics**:
- `'everyday'`: each new day's entry starts at 0 (default behavior since entries are per-day)
- `'none'`: for `achieve_all` — shows as completed if any historical completion exists (persists across days until toggled off); for `certain_amount` — carries over the last entry's amount as today's starting value

### Calendar feature (`lib/src/calendar/calendar_view.dart`)

`CalendarView` uses `CustomScrollView(center: _centerKey)` for true bidirectional infinite scroll (600 months back + current + 600 forward ≈ 50 years each way):

- **Why `center:`**: `SliverList` with variable-height items must build all preceding items before showing any given offset. With a large `initialScrollOffset`, Flutter would need to pre-build hundreds of off-screen months. Using `CustomScrollView(center: _centerKey)` anchors the viewport at the current month (scroll offset 0) — past months build lazily only when the user scrolls up.
- **Layout**: `CupertinoPageScaffold` with standard `CupertinoNavigationBar` (shows `_visibleYear`, updated by scroll listener using `_avgMonthPx ≈ 481` approximation) + a fixed `_WeekdayHeader` row (Mon–Sun) + `Expanded(CustomScrollView(...))`.
- **Past SliverList**: laid out bottom-to-top by Flutter. Index 0 = last month (sits just above current), index N = N+1 months ago (further up).
- **Reset signal**: `animateTo(0.0)` snaps/animates back to the current month.
- **Day cells**: 88px min height, up to 3 orange task chips (uncompleted only) + `+N` overflow label. Monday-first grid.

### Design tokens

- Accent color: `Color(0xFFFF4D00)` (orange-red)
- Active tab label/icon: black (`Color(0xFF000000)`)
- Inactive tab: `Color(0xFF636366)`
- Checkbox: 22×22 rounded rect (radius 6), filled accent when checked
- All transitions: 180 ms (`FastRoute`)

### Localization

String resources in `lib/src/localization/app_en.arb`. Run `flutter gen-l10n` after editing. Both `GlobalMaterialLocalizations.delegate` and `GlobalCupertinoLocalizations.delegate` are registered (Material delegate is needed for `showModalBottomSheet`).
