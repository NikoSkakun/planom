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
- **Database**: `sqflite` v2, single file `planom.db`, current schema version **14**
- **State**: Flutter `ChangeNotifier` — no third-party state library
- **Routing**: `FastRoute` (custom `CupertinoPageRoute` subclass with 180 ms transition, in `lib/src/utils/fast_route.dart`) used everywhere instead of bare `CupertinoPageRoute`
- **Icons**: `cupertino_icons` package required for `CupertinoIcons`; custom PNG tab-bar icons in `assets/icons/tab_bar/` (Tasks/Notes/Calendar/Routines use PNGs; Settings tab uses `CupertinoIcons.gear_alt` / `gear_alt_fill`); list icons (`inbox.png`, `today.png`, `upcoming.png`, `folder.png`, `list.png`) in `assets/icons/`; use `Image.asset` (not `ImageIcon`) when original PNG colors must be preserved. Smart lists that have no PNG asset (Completed, Trash) use `CupertinoIcons` passed as `iconWidget` to `_ListItem`.
- **App badge**: `flutter_app_badger ^1.5.0` (discontinued but functional) — set by `TaskController._updateBadge()` to `todayUncompletedCount`; iOS badge permission requested in `AppDelegate.swift` via `UNUserNotificationCenter`
- **Backup / share**: `share_plus ^7.2.1` — iOS share sheet for exporting `.planom` backup files; `file_picker ^8.0.0` — document picker for importing backup files

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
  priority: int               ← TaskPriority.index (0=none 1=low 2=medium 3=high)
  sortOrder: int              ← 0 = not yet manually sorted; >0 = user-defined position
  isDeleted: bool             ← soft-delete flag; true = item is in Trash
  deletedDate: DateTime?      ← when the item was moved to Trash

AppFolder (lib/src/models/app_folder.dart)   ← NOT an AppItem
  id: String (UUID v4)
  name: String
  parentFolderId: String?     ← null = root level
  creationDate: DateTime
  sortOrder: int
  iconId: String?             ← null = default folder asset; SF-symbol key or relative file path (see custom icons)
  isDeleted: bool
  deletedDate: DateTime?

AppList (lib/src/models/app_list.dart)   ← NOT an AppItem
  id: String (UUID v4)
  name: String
  folderId: String?           ← null = root level
  creationDate: DateTime
  sortOrder: int
  color: int?                 ← ARGB; null = no color accent
  iconId: String?             ← null = default list asset; SF-symbol key or relative file path (see custom icons)
  isDeleted: bool
  deletedDate: DateTime?

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

`Task.copyWith` accepts clear-flags (`clearDueDate`, `clearDoTime`, `clearListId`, `clearDeletedDate`) to explicitly null out nullable fields — the standard Dart nullable-copyWith pattern used throughout. `AppFolder.copyWith` and `AppList.copyWith` follow the same pattern. Item spacing: task rows use `vertical: 7` padding; list/folder items use `vertical: 9` in custom `GestureDetector` rows (not `CupertinoListTile.notched`).

### Soft-delete pattern

**All deletes are soft-deletes.** Nothing is removed from the database immediately — items get `isDeleted = true` and `deletedDate = now`, then move into a Trash in-memory list inside the controller. The DB queries for active items filter `WHERE isDeleted = 0`.

- `TaskController.deleteTask(id)` — moves task from `_tasks` to `_trashedTasks`
- `TaskController.deleteTasksForList(listId)` — bulk soft-deletes all tasks for a list (called when a list is trashed)
- `FolderController.deleteList(id)` — soft-deletes the list
- `FolderController.deleteFolderDeep(id, onDeleteList)` — recursively soft-deletes the folder, all nested subfolders, all their lists (`onDeleteList` is called per list so the task controller can also soft-delete tasks); all items in the same deep-delete share the same `deletedDate` timestamp
- Swipe-to-delete on lists and folders shows a `confirmDismiss` `CupertinoAlertDialog` before acting; the Dismissible bounces back if the user cancels
- Items are restored via `restoreTask / restoreList / restoreFolder`; the restore target is the original parent if it is still active (non-trashed), else the item falls back to Inbox / root

Permanent deletion (from Trash) removes the row from the DB:
- `TaskController.permanentlyDeleteTask(id)`
- `TaskController.permanentlyDeleteAllTrashed()` — bulk hard-delete all trashed tasks
- `FolderController.permanentlyDeleteList(id)`
- `FolderController.permanentlyDeleteFolder(id)`
- `FolderController.permanentlyDeleteAllTrashed()` — bulk hard-delete all trashed lists and folders

### Custom icon storage (`lib/src/folders/folder_icon_picker.dart`)

Custom photo icons for folders and lists are stored as **relative paths** (`icons/<timestamp>.<ext>`) under the app's documents directory. This is critical for iOS — absolute paths break after every reinstall because the app container UUID changes.

- `initFolderIconService()` — called once in `main.dart` before `runApp`; caches `getApplicationDocumentsDirectory()` so path resolution is synchronous during widget builds
- `isCustomIconId(iconId)` — returns `true` for relative paths (`icons/…`) and legacy absolute paths (`/…`)
- `resolveCustomIconPath(iconId)` — returns the absolute path at runtime using the cached docs dir; handles both new relative format and legacy absolute paths (with graceful fallback)
- `buildFolderItemIcon(iconId, isFolder)` — synchronous widget builder; uses `resolveCustomIconPath` for custom icons and `folderItemIconData` for SF-symbol keys; falls back to the default PNG on error
- **Legacy absolute paths** (stored before this fix) still display if the file exists (e.g. on first launch after an in-place update on device), and fall back to the default icon otherwise; re-picking the icon writes the new relative format

### Database (`lib/src/database/database_service.dart`)

Single `DatabaseService` class, lazy-opens `planom.db` via sqflite. Current version: **14**.

Migration history:
| Version | Changes |
|---------|---------|
| v2 | `tasks.dueDate INTEGER` |
| v3 | `tasks.listId TEXT` + `folders` + `app_lists` tables |
| v4 | `tasks.doTime INTEGER`; `folders` / `app_lists` tables (IF NOT EXISTS guard) |
| v5 | `note_folders` + `notes` tables |
| v6 | `routines` + `routine_entries` tables |
| v7 | `tasks.priority`, `tasks.sortOrder`, `folders.sortOrder`, `app_lists.sortOrder`, `note_folders.sortOrder`, `notes.sortOrder` |
| v8 | `app_lists.color INTEGER` |
| v9 | `folders.iconId TEXT`, `app_lists.iconId TEXT` |
| v10 | `note_folders.iconId TEXT` |
| v11 | `tasks.isDeleted`, `tasks.deletedDate`, `folders.isDeleted`, `folders.deletedDate`, `app_lists.isDeleted`, `app_lists.deletedDate` |
| v12 | `note_folders.isDeleted`, `note_folders.deletedDate`, `notes.isDeleted`, `notes.deletedDate` |
| v13 | `tasks.completionDate INTEGER` |
| v14 | `app_settings` table (`key` TEXT PK, `value` TEXT) — persists tab visibility prefs across backups |

When adding new tables/columns, bump `_dbVersion` and add an `onUpgrade` branch.

Key query methods (tasks):
- `getTasks()` — active only (`isDeleted = 0`), sorted by `sortOrder ASC, creationDate DESC`
- `getTrashedTasks()` — `isDeleted = 1`, sorted by `deletedDate DESC`
- `softDeleteTask(id, deletedDate)` / `softDeleteTasksForList(listId, deletedDate)`
- `restoreTask(id)` — sets `isDeleted = 0, deletedDate = NULL`
- `permanentlyDeleteTask(id)` — hard `DELETE`
- `clearTrashedTasks()` / `clearTrashedFolders()` / `clearTrashedLists()` — bulk `DELETE WHERE isDeleted = 1` (used by "Empty Trash")

Equivalent soft-delete/restore/trash methods exist for `folders` and `app_lists`.

Backup methods (no filters — export includes active + trashed items):
- `exportTasks()` / `exportFolders()` / `exportLists()` / `exportNoteFolders()` / `exportNotes()` / `exportRoutines()` / `exportRoutineEntries()` — return `List<Map<String, dynamic>>` (raw sqflite rows)
- `clearAllData()` — deletes all rows from all 7 tables (used before import)
- `importTasks(maps)` / `importFolders(maps)` / `importLists(maps)` / `importNoteFolders(maps)` / `importNotes(maps)` / `importRoutines(maps)` / `importRoutineEntries(maps)` — batch-insert from raw maps

Routine DB schema:
- `routines` — stores routine definitions (all Routine fields; `weekdays` stored as comma-separated string e.g. `"0,1,2,3,4,5,6"`)
- `routine_entries` — per-day progress records; one row per (routineId, date); `amount` is cumulative for the day

### Controllers

**`TaskController`** (`lib/src/tasks/task_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → individual views
- Owns two in-memory lists: `_tasks` (active) and `_trashedTasks` (soft-deleted)
- Key API:
  - `inboxTasks`, `inboxUncompletedCount`
  - `todayTasks`, `todayUncompletedCount`
  - `upcomingTasks`, `upcomingUncompletedCount`
  - `tasksForList(listId)`, `uncompletedCountForList(listId)`, `tasksForDate(date)`
  - `allCompletedTasks` — all non-trashed completed tasks across every list/inbox
  - `completedTasksCount` — length of above (used to show/hide the Completed smart list)
  - `trashedTasks` — read-only view of `_trashedTasks`
  - `addTask`, `updateTask`, `toggleCompleted`
  - `deleteTask(id)` — soft-delete (moves to `_trashedTasks`)
  - `deleteTasksForList(listId)` — bulk soft-delete (called when list is trashed)
  - `restoreTask(id, targetListId)` — moves from `_trashedTasks` back to `_tasks`; if `targetListId` differs from the original `listId` (e.g. list was trashed), updates the DB row too
  - `permanentlyDeleteTask(id)` — hard delete from `_trashedTasks` + DB
  - `permanentlyDeleteAllTrashed()` — bulk hard-delete all items in `_trashedTasks`; used by "Empty Trash"
  - `sortOrder` / `setSortOrder(TaskSortOrder)` — affects all list views
  - `reorderTasks({listId, oldIndex, newIndex})` — manual drag reorder within a scope

**`FolderController`** (`lib/src/folders/folder_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → task-related views
- Owns four in-memory lists: `_folders`, `_lists`, `_trashedFolders`, `_trashedLists`
- Key API:
  - `foldersIn(parentId?)` — active folders at a given level, sorted by `sortOrder`
  - `listsIn(folderId?)` — active lists at a given level, sorted by `sortOrder`
  - `listById(id)` — lookup in active lists only (used for trash restore-path resolution)
  - `folderById(id)` — lookup in active folders only
  - `trashedFolders`, `trashedLists` — read-only views
  - `addFolder`, `addList`, `updateFolder`, `updateList`
  - `deleteList(id)` — soft-delete (moves to `_trashedLists`)
  - `deleteFolderDeep(id, onDeleteList)` — recursive soft-delete; `onDeleteList` is `TaskController.deleteTasksForList`
  - `restoreList(id, targetFolderId)`, `restoreFolder(id, targetParentId)`
  - `permanentlyDeleteList(id)`, `permanentlyDeleteFolder(id)`
  - `permanentlyDeleteAllTrashed()` — bulk hard-delete all trashed lists and folders; used by "Empty Trash"
  - `reorderFolders(parentId?, old, new)`, `reorderLists(folderId?, old, new)`

**`RoutineController`** (`lib/src/routines/routine_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → `RoutinesView`
- Key API: `todayRoutines`, `entryForToday(routineId)`, `todayProgress(routineId)`, `isTodayCompleted(Routine)`, `recordProgress(Routine)`, `addRoutine`, `updateRoutine`, `deleteRoutine`, `load`
- `todayRoutines` filters `_routines` by schedule: `daily` checks weekday membership; `days_after_complete` shows routine when `today >= lastCompletionDate + gap`
- `recordProgress` toggles for `achieve_all` (0↔1) and increments by `recordAmount` for `certain_amount`; creates today's entry if absent
- `autoReset='none'`: carries over last known amount as today's starting value; for `achieve_all` shows as done if any historical completion exists (until toggled off today)
- Weekdays stored as `List<int>` (0=Mon … 6=Sun); Dart's `DateTime.weekday` is 1=Mon, so always subtract 1 when comparing

**`NoteController`** (`lib/src/notes/note_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → `NotesView`
- Owns four in-memory lists: `_notes`, `_folders`, `_trashedNotes`, `_trashedFolders`; mirrors the `FolderController` API for the notes domain
- Soft-delete: `deleteNote(id)`, `deleteFolderDeep(id)` (recursive — no callback needed since notes have no cross-controller dependency)
- Restore: `restoreNote(id, targetFolderId)`, `restoreFolder(id, targetParentId)` — fall back to root if the original parent is trashed
- `permanentlyDeleteNote(id)`, `permanentlyDeleteFolder(id)`, `permanentlyDeleteAllTrashed()` — bulk hard-delete from Trash
- Reorder helpers mirror folder/list reorder behavior

**`SettingsController`** (`lib/src/settings/settings_controller.dart`)
- Manages `ThemeMode` (persisted via `SettingsService` → `SharedPreferences`)
- Owns `SmartListPrefs` (visibility of Today/Upcoming/Completed/Trash smart lists + `hideTabLabels` toggle), persisted to a JSON file in the documents directory
- Owns per-tab visibility (`_tabVisibility` map for tabs 1=Notes, 2=Calendar, 3=Routines, 4=Settings; tab 0 always on), persisted to the `app_settings` DB table so backups carry it across devices
- `visibleOptionalTabCount` — number of optional tabs currently enabled; used to gray out the last toggle (UI prevents disabling all of them)
- `importSmartListPrefs(map)` — invoked by `BackupService` during import to restore the JSON-backed prefs

**`BackupService`** (`lib/src/settings/backup_service.dart`)
- Not a `ChangeNotifier`; created in `main.dart` alongside controllers and passed through `MyApp` → `HomeShell` → `SettingsView`
- `exportBackup()` — reads all 7 tables (including trashed items), collects custom icon image bytes (base64), serialises `SettingsController.smartListPrefs` alongside the DB rows, writes a `planom_backup_YYYY-MM-DD.planom` JSON file to the temp directory, shares it via iOS share sheet. Custom iconIds are normalised to relative paths (`icons/<filename>`) in the export; image bytes are stored under a top-level `customIcons` map keyed by relative path.
- `importBackup()` — opens the file picker, parses the JSON, writes custom icon files to `<docsDir>/icons/`, clears all DB tables, bulk-inserts all records, restores smart-list prefs from `smart_list_prefs`, then calls `load()` on each controller. Returns `true` on success, `false` if the file was invalid or the picker was cancelled.
- Backup format: JSON with `.planom` extension, `version: 1`. Top-level keys: `version`, `exportDate`, `customIcons`, `tasks`, `folders`, `app_lists`, `note_folders`, `notes`, `routines`, `routine_entries`, `app_settings`, `smart_list_prefs`.

### App shell (`lib/src/home_shell.dart`)

`HomeShell` is a `StatefulWidget` that wraps a `CupertinoTabScaffold` (up to **5 tabs**: Tasks(0) always-on, then Notes(1) / Calendar(2) / Routines(3) / Settings(4) — each toggleable in Settings → Tab Bar) in a `Stack` with a floating accent-colored `+` button (52×52, `AppColors.accent`) above the tab bar. `_computeVisibleIndices()` produces the logical→visual index mapping based on `SettingsController.isTabVisible`; the scaffold is keyed by `ValueKey(visibleIndices.join(','))` so a clean rebuild happens whenever the visible set changes. When the Settings tab is hidden, every other tab's root view exposes a ⋯ button (Tasks via its dropdown menu, Notes/Calendar/Routines via the nav-bar trailing icon) that pushes `SettingsView` on the current tab's navigator. Key state:
- `_navigatorKeys`: per-tab `GlobalKey<NavigatorState>` — used to pop-to-root on same-tab re-tap
- `_depthObservers`: per-tab `_DepthObserver extends NavigatorObserver` — tracks push/pop depth AND counts routes matching `trackedRouteName`
- `_showPlusButton`: `ValueNotifier<bool>` toggled by `_depthObservers`; passed to `ValueListenableBuilder` that wraps the `Positioned` button
- `_activeListId` / `_activeDueDate`: `ValueNotifier<T?>` that child views set to pre-fill the task creation sheet's list and date
- `_calendarResetSignal`: `ValueNotifier<int>` incremented when Calendar tab is re-tapped, causing `CalendarView` to scroll back to current month
- `_lastTabIndex`: tracks last tapped tab to detect same-tab re-tap via `CupertinoTabBar.onTap`

**Plus button visibility rules:**
- **Tab 0 (Tasks)**: shown whenever no `TaskDetailView` is on the stack — i.e. `_depthObservers[0].trackedCount == 0`. Visible on TasksView, InboxView, TodayView, CompletedView, TrashView, FolderView, ListTaskView at any nesting depth; hidden only inside the task edit screen.
- **Tab 1 (Notes)**: always hidden — Notes manages its own UI.
- **Tabs 2 & 3 (Calendar / Routines)**: hidden when depth > 1 (any push beyond the tab root).
- **Tab 4 (Settings)**: always hidden.
- `_DepthObserver` accepts an optional `trackedRouteName`; `trackedCount` increments/decrements as matching routes are pushed/popped. Tab 0's observer tracks `'task_detail'`.
- All `TaskDetailView` pushes use `RouteSettings(name: TaskDetailView.routeName)` (`'task_detail'`) so the observer can identify them.

**Plus button action (`_onPlusPressed`):**
- `_lastTabIndex == 3` (Routines): pushes `RoutineCreationView` on the Routines tab navigator via `_navigatorKeys[3]` — this increments depth to 2, hiding the button automatically.
- All other tabs: shows `TaskCreationSheet` modal (root navigator).

### Navigation

- `MyApp.onGenerateRoute` in `app.dart` routes the root `/` to `HomeShell` (the only top-level destination) using `FastRoute`
- In-tab navigation (e.g. Tasks → Inbox, Inbox → TaskDetail) uses `Navigator.of(context).push(FastRoute(...))` directly
- Settings is a dedicated tab (index 4); it is no longer registered as a pushed route inside individual tab navigators

### Tasks feature (`lib/src/tasks/`)

| File | Purpose |
|------|---------|
| `tasks_view.dart` | Tab root; three sections: (1) smart lists top (Inbox/Today/Upcoming + separator), (2) reorderable user folders + lists, (3) smart lists bottom (Completed + Trash, each conditional) + separator |
| `inbox_view.dart` | Active tasks with `listId = null`; swipe-to-delete sends to Trash; tap row → `TaskDetailView`, tap checkbox → toggle; no dividers |
| `today_view.dart` | Tasks due today + overdue (`dueDate ≤ today`); sets `activeDueDate` so `+` pre-fills today; overdue tasks show date in red |
| `upcoming_view.dart` | Tasks with `dueDate > today`, sorted by date; grouped by date header |
| `completed_view.dart` | All non-trashed completed tasks across every scope; swipe-to-delete sends to Trash; no count badge on entry |
| `trash_view.dart` | All trashed tasks + lists + folders, sorted by `deletedDate DESC`; **swipe right → Put Back** (blue, confirmation shows restore destination); **swipe left → Delete Permanently** (red, confirmation required); **`⋯` nav bar button → Empty Trash** (action sheet + confirmation dialog, only shown when trash is non-empty); no count badge on entry |
| `task_detail_view.dart` | Edit screen; "Done" nav bar button saves via `controller.updateTask`; `routeName = 'task_detail'` used by `_DepthObserver` to hide the global `+` button |
| `task_creation_sheet.dart` | Modal bottom sheet (root navigator); title (sentence-cap) + note + date + list picker + Add; accepts `initialListId` and `initialDueDate` |
| `calendar_date_picker.dart` | Date+time picker dialog; `formatTaskDate(DateTime, {int? doTime})` and `formatDoTime(int)` helpers; returns `(DateTime?, int?)?` — outer null = barrier dismiss (no change), `(null,null)` = No Date, `(date, time?)` = selection |
| `task_controller.dart` | `ChangeNotifier` wrapping `DatabaseService`; manages `_tasks` + `_trashedTasks`; `deleteTask` is soft-delete; iOS badge via `flutter_app_badger` |
| `task_row.dart` | `TaskRow` widget + `TaskDeleteBackground` + `taskProxyDecorator` shared across list views |

**TaskController ordering**: `inboxTasks`, `tasksForList`, and `todayTasks` all pass through `_completedLast()` — incomplete tasks first, completed at the bottom. Unchecking a task restores it to the incomplete group (not its original position).

**`todayTasks` / `todayUncompletedCount`**: includes all tasks where `dueDate` (normalized to midnight) is ≤ today — i.e. today's tasks plus any overdue tasks. `todayUncompletedCount` derives from `todayTasks`, so the iOS app badge automatically counts overdue uncompleted tasks.

**`TaskSortOrder` enum**: `defaultOrder | creationDate | name | priority | dateTime`. Only `defaultOrder` enables drag-reorder; other sort orders disable `SliverReorderableList` (`enabled: false` on the listener).

**Smart list visibility rules** in `tasks_view.dart`:
- **Completed**: shown only when `controller.completedTasksCount > 0`
- **Trash**: shown only when there is at least one trashed task, list, or folder

**Dismissal pattern for lists/folders**: Uses `Dismissible.confirmDismiss` → `CupertinoAlertDialog` asking "Move to Trash?"; returns `false` (bounces back) on cancel. The `onDismissed` callback then calls the appropriate soft-delete on the controller.

**List/folder row items** (`_ListItem` in `tasks_view.dart`, `_FolderListItem` in `folder_view.dart`): no chevron icon — rows show icon + label + optional uncompleted count only. `_ListItem` accepts either `iconAsset` (PNG path), `iconId` (SF-symbol key via `buildFolderItemIcon`), or `iconWidget` (arbitrary widget, used for Completed/Trash).

### Folders feature (`lib/src/folders/`)

| File | Purpose |
|------|---------|
| `folder_view.dart` | Subfolder/list browser inside a folder; reorderable via `SliverReorderableList`; swipe-to-delete with `confirmDismiss` dialog; bottom `+` button opens `CreateFolderListSheet` scoped to this folder |
| `list_task_view.dart` | Task list for a named list; sets `activeListId` on enter/exit so the global `+` pre-fills the list; dropdown menu for icon/color change |
| `folder_controller.dart` | Owns `_folders`, `_lists`, `_trashedFolders`, `_trashedLists`; soft-delete and restore; recursive `deleteFolderDeep` |
| `folder_icon_picker.dart` | Custom icon storage and rendering. `initFolderIconService()` caches docs dir at startup. `buildFolderItemIcon(iconId, isFolder)` renders a 22×22 icon (file image, SF-symbol, or default PNG). `isCustomIconId(iconId)` / `resolveCustomIconPath(iconId)` — path helpers. `showFolderIconPickerSheet` — modal picker that writes relative paths (`icons/<ts>.<ext>`). |
| `create_folder_list_sheet.dart` | `showCreateFolderListSheet` — bottom sheet to create a new folder or list, optionally scoped to a parent folder |
| `list_color_picker.dart` | Color swatch picker for list accent color |

### Settings feature (`lib/src/settings/`)

| File | Purpose |
|------|---------|
| `settings_controller.dart` | `ChangeNotifier` managing `ThemeMode`; persisted via `SettingsService` |
| `settings_service.dart` | Persists `ThemeMode` to `SharedPreferences` |
| `settings_view.dart` | Settings tab root (`StatefulWidget`); **Appearance** section (Light/System/Dark segmented control); **Data** section with Export Backup and Import Backup rows (only rendered when `backupService` is non-null). Loading spinner shown in place of chevron while operation is in progress. |
| `backup_service.dart` | `exportBackup()` — serialises all data + custom icon image bytes to `.planom` JSON, shares via share sheet. `importBackup()` — picks a file, validates, restores icon files, clears DB, re-inserts data, reloads all controllers. |

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

All colors and durations live in `lib/src/theme/app_theme.dart`. Use the constants — never hard-code these values at call sites.
- `AppColors.accent` (`0xFFFF4D00`) — primary brand accent
- `AppColors.systemGreen` (`0xFF34C759`) — completed indicators
- `AppColors.shadow` (`0x30000000`) — dropdown / panel drop-shadow
- `AppDurations.transition` (180 ms) — standard page transition; baked into `FastRoute`
- Active tab label/icon: black (`Color(0xFF000000)`)
- Inactive tab: `Color(0xFF636366)`
- Checkbox: 22×22 rounded rect (radius 6), filled accent when checked

### Shared utilities (`lib/src/utils/`)

- `fast_route.dart` — `FastRoute<T>` `CupertinoPageRoute` subclass with 180 ms transition. **Always use FastRoute, never bare `CupertinoPageRoute`.**
- `dropdown_overlay.dart` — `DropdownOverlayMixin` on `State<T>`: provides `showDropdown(context, builder)` that inserts an `OverlayEntry`, exposes a `dismiss()` callback to the builder, and auto-removes the entry in `dispose()` so the overlay can't leak when the host route is popped while the menu is open.
- `confirm_dialogs.dart` — `confirmMoveToTrash(context, name:, body:, isFolder:)` returns `Future<bool>`; the canonical "Move to Trash?" Cupertino dialog used by every soft-delete site.
- `item_info_sheet.dart` — `showItemInfoSheet(context, ...)` modal showing creation/modified/completion dates for a task/note/folder.

### Localization

String resources in `lib/src/localization/app_en.arb`. Run `flutter gen-l10n` after editing. Both `GlobalMaterialLocalizations.delegate` and `GlobalCupertinoLocalizations.delegate` are registered (Material delegate is needed for `showModalBottomSheet`).
