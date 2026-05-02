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
- **Database**: `sqflite` v2, single file `planom.db`, current schema version 2
- **State**: Flutter `ChangeNotifier` — no third-party state library
- **Routing**: `FastRoute` (custom `CupertinoPageRoute` subclass with 180 ms transition, in `lib/src/utils/fast_route.dart`) used everywhere instead of bare `CupertinoPageRoute`
- **Icons**: `cupertino_icons` package required for `CupertinoIcons`; custom PNG tab-bar icons in `assets/icons/tab_bar/`; list icons (`inbox.png`, `today.png`, `folder.png`) in `assets/icons/`; use `Image.asset` (not `ImageIcon`) when original PNG colors must be preserved

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
```

`Task.copyWith` accepts `clearDueDate: bool` to explicitly null out `dueDate` (standard Dart nullable-copyWith pattern).

Future types (`Note`, `Routine`) should also extend `AppItem`.

### Database (`lib/src/database/database_service.dart`)

Single `DatabaseService` class, lazy-opens `planom.db` via sqflite. Current version: **2** (v1→v2 migration adds `dueDate INTEGER` column). When adding new tables/columns, bump `_dbVersion` and add an `onUpgrade` branch.

### Controllers

**`TaskController`** (`lib/src/tasks/task_controller.dart`)
- Initialized in `main.dart`, passed through `MyApp` → `HomeShell` → individual views
- Key API: `inboxTasks`, `inboxUncompletedCount`, `todayTasks`, `tasksForDate(DateTime)`, `addTask`, `updateTask`, `toggleCompleted`, `load`

**`SettingsController`** (`lib/src/settings/settings_controller.dart`)
- Manages `ThemeMode`; mapped to `CupertinoThemeData.brightness` in `app.dart`

### App shell (`lib/src/home_shell.dart`)

`HomeShell` wraps a `CupertinoTabScaffold` (3 tabs: Tasks / Calendar / Routines) in a `Stack` with a floating orange `+` button (52×52, `Color(0xFFFF4D00)`) positioned above the tab bar. The button calls `showTaskCreationSheet`. Both `settingsController` and `taskController` are passed into `HomeShell`.

### Navigation

- `MyApp.onGenerateRoute` in `app.dart` handles the root `/` and `/settings` routes using `FastRoute`
- In-tab navigation (e.g. Tasks → Inbox, Inbox → TaskDetail) uses `Navigator.of(context).push(FastRoute(...))` directly
- `CupertinoTabView.routes` registers the `/settings` route inside each tab so it pushes within the tab navigator

### Tasks feature (`lib/src/tasks/`)

| File | Purpose |
|------|---------|
| `tasks_view.dart` | Tab root; shows Inbox + Today list items with icons and uncompleted count badge |
| `inbox_view.dart` | Task list; tap row body → `TaskDetailView`, tap checkbox → toggle |
| `task_detail_view.dart` | Edit screen; "Done" nav bar button saves via `controller.updateTask` |
| `task_creation_sheet.dart` | Modal bottom sheet (root navigator); title + note + date button + Add |
| `date_picker_sheet.dart` | Shared `DatePickerSheet` widget + `formatTaskDate` helper used by both sheet and detail view |
| `task_controller.dart` | ChangeNotifier wrapping DatabaseService |

### Calendar feature (`lib/src/calendar/calendar_view.dart`)

`CalendarView` is a `StatefulWidget` that renders 16 months (3 past + current + 12 future) in a `CustomScrollView` with `CupertinoSliverNavigationBar`. On first frame it scrolls to the current month via `Scrollable.ensureVisible`. Each day cell shows up to 2 task chips (orange = active, gray = completed) keyed by `task.dueDate`. Uses `controller.tasksForDate(date)`.

### Design tokens

- Accent color: `Color(0xFFFF4D00)` (orange-red)
- Active tab label/icon: black (`Color(0xFF000000)`)
- Inactive tab: `Color(0xFF636366)`
- Checkbox: 22×22 rounded rect (radius 6), filled accent when checked
- All transitions: 180 ms (`FastRoute`)

### Localization

String resources in `lib/src/localization/app_en.arb`. Run `flutter gen-l10n` after editing. Both `GlobalMaterialLocalizations.delegate` and `GlobalCupertinoLocalizations.delegate` are registered (Material delegate is needed for `showModalBottomSheet`).
