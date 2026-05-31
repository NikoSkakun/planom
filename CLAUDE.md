# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis / lint
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter run              # Run on connected device or emulator
```

Flutter binary is at `~/dev/flutter/bin/flutter` (not on PATH by default).

> Localization is **hand-rolled** in `lib/src/localization/strings.dart` (no `gen-l10n` / `.arb` codegen). Add new keys to the `_translations` map there — there is no build step. A stale `app_en.arb` file is kept in-tree but unused. See "Localization" below.

## Tech stack

- **Framework**: Flutter / Dart, Cupertino (iOS-native) widgets throughout — no Material widgets in UI except `showModalBottomSheet` (which requires `GlobalMaterialLocalizations.delegate` already registered)
- **Database**: `sqflite` v2 (mobile/macOS), `sqflite_common_ffi` (Linux/Windows). Per-space DB files (default space = `planom.db`, others `planom_<id>.db`), current schema version **28**. FTS5 virtual tables for search.
- **Multi-space**: `SpaceManager` (`lib/src/spaces/`) owns a list of `Space`s and swaps the active space's controllers; the default space shares the global `planom.db` handle.
- **App lock**: `SecurityService` (`lib/src/security/`) — optional PIN (4–8 digit) / custom password + optional biometric (Face ID, Touch ID, Windows Hello via `local_auth`); salted + key-stretched PBKDF2/HMAC-SHA256 hash in `app_settings` (`auth_*` keys), excluded from backups.
- **Local notifications**: `NotificationService` (`lib/src/notifications/`) — `flutter_local_notifications` + `timezone`; per-task / per-event reminder scheduling via slot-based IDs. iOS + macOS only today.
- **Calendar/events**: `EventController` + `events` table (separate from tasks); see Calendar feature.
- **Contacts (birthdays)**: `ContactController` + `contacts` table; lists with `listType = birthdays` render contacts instead of tasks (see Contacts feature).
- **Cloud sync**: `SyncController` (`lib/src/sync/`) + backend-agnostic `SyncProvider`; iCloud Drive provider shipped (`icloud_storage`). Optional E2E AES-256-GCM encryption via passphrase in `flutter_secure_storage`. See Sync section.
- **MCP server**: `lib/src/mcp/` — transport-agnostic JSON-RPC 2.0 server exposing tasks/notes/events/lists/spaces/search. See MCP section.
- **State**: Flutter `ChangeNotifier` — no third-party state library.
- **Routing**: `FastRoute` (custom `CupertinoPageRoute` subclass with 180 ms transition, in `lib/src/utils/fast_route.dart`) used everywhere instead of bare `CupertinoPageRoute`.
- **Icons**: `cupertino_icons`; custom PNG tab-bar icons in `assets/icons/tab_bar/` (Tasks/Notes/Calendar/Routines use PNGs; Settings uses `CupertinoIcons.gear_alt` / `gear_alt_fill`); list icons (`inbox.png`, `today.png`, `upcoming.png`, `folder.png`, `list.png`) in `assets/icons/`.
- **App badge**: `flutter_app_badger ^1.5.0` (discontinued but functional) — set by `TaskController._updateBadge()` to `todayUncompletedCount`. Gated to mobile via `PlatformCapabilities.supportsAppBadge`.
- **Backup / share**: `share_plus` (iOS/Android/macOS share sheet) for `.planom` files; `file_picker` for document picker import. `pdf` for note PDF export. `image_picker` (mobile) + `file_picker` (desktop) for custom-icon photo selection.
- **Markdown**: `flutter_markdown` for note rendering; custom inline-markdown stripper used in note-row previews.
- **Fonts**: `google_fonts` — full ~1500-font catalogue exposed via the in-app Font Picker; cached at `<appSupport>/google_fonts/` automatically.
- **Google Calendar**: `google_sign_in` + `googleapis` + `extension_google_sign_in_as_googleapis_auth` (see Google Calendar integration). Optional — disabled until client IDs are configured.

## Platforms

Centralised in `PlatformCapabilities` (`lib/src/utils/platform_capabilities.dart`). Use the predicates — never `Platform.isX` at call sites.

- `isMobile` (iOS + Android) — gates `flutter_app_badger`, `SystemChrome.setPreferredOrientations`, `image_picker`'s system gallery.
- `isDesktop` (macOS + Linux + Windows) — Planom always uses the iPad sidebar layout regardless of window width on these platforms.
- `sqfliteNeedsFfi` (Linux + Windows) — `main.dart` swaps in `databaseFactoryFfi` from `sqflite_common_ffi` before any controller opens a DB.
- `supportsBiometricAuth` (iOS + Android + Windows) — macOS/Linux have no `local_auth` implementation; PIN/password fallback only.
- `supportsLocalNotifications` (iOS + macOS today) — Android/Linux/Windows would need their own `InitializationSettings`.
- `supportsImagePicker` (mobile) — desktop falls back to `file_picker` with image filetype filters.

iPad-sized layout (width ≥ 700 px) and all desktop platforms use a persistent sidebar (`_WideLayout` in `home_shell.dart`) instead of the bottom `CupertinoTabBar`.

## Architecture

Source lives in `lib/src/` with a three-layer pattern:

- **Models** (`lib/src/models/`) — plain Dart. `Task`/`Routine` extend the `AppItem` base; `AppFolder`/`AppList`/`Note`/`NoteFolder`/`Contact`/`Event`/`RoutineEntry`/`ListSection`/`Tag` are standalone.
- **Services** (`*_service.dart`) — I/O only, called by controllers.
- **Controllers** (`*_controller.dart`) — `ChangeNotifier`; own in-memory state, persist via services, call `notifyListeners()` after mutations.
- **Views** (`*_view.dart`) — Cupertino widgets, subscribe via `ListenableBuilder` / `ValueListenableBuilder`.

### Data model hierarchy

```
AppItem (lib/src/models/item.dart)         ← base for Task & Routine
  id: String (UUID v4)
  creationDate: DateTime
  iconId: String

Task extends AppItem (lib/src/models/task.dart)
  title, note?, isCompleted
  dueDate?, doTime? (mins since midnight, 0–1439), duration? (mins)
  listId?, sectionId?                ← null sectionId = default top section
  priority (0=none 1=low 2=medium 3=high)
  sortOrder                          ← 0 = unsorted; >0 user position
  isDeleted, deletedDate?
  completionDate?
  reminderOffsets: List<int>         ← minutes before/after dueDate+doTime
  parentTaskId?                      ← non-null = subtask; excluded from smart lists
  tagIds: List<String>               ← references tags table
  recurrence?                        ← JSON-encoded Recurrence rule

Routine extends AppItem (lib/src/models/routine.dart)
  name, iconColor (ARGB; iconId is an SF-symbol key OR a custom photo path
                   — `icons/…`, same storage as folders/lists)
  goalType ('achieve_all' | 'certain_amount')
  goalAmount?, goalUnit?, recordAmount?   ← certain_amount only
  frequencyType ('daily' | 'specific_days' | 'interval')
  weekdays?: List<int>               ← specific_days only: 0=Mon … 6=Sun, ≥1 day
  startDate?: DateTime               ← day the routine starts (falls back to
                                       creationDate when null)
  intervalDays?: int                 ← interval only: appears every N days
  waitForCompletion: bool            ← interval only: next occurrence is anchored
                                       to the completion date; a missed occurrence
                                       stays overdue and shifts future ones
  reminders: List<RoutineReminder>   ← per-routine reminders (see below)

RoutineReminder (lib/src/models/routine_reminder.dart)  ← NOT an AppItem
  type ('time' | 'spread' | 'afterEach'), value (minute-of-day or delay mins),
       interval? (spread: minutes between reminders)
  time      = fixed clock time, fires once per active day
  spread    = amount goals: from `value`, one reminder every `interval` mins,
              one per planned iteration through the day
  afterEach = amount goals: `value` mins after each logged unit (scheduled
              reactively in RoutineController.recordProgress)
  JSON-encoded into Routine.reminders

AppFolder (lib/src/models/app_folder.dart)
  name, parentFolderId?, sortOrder, iconId?, iconColor? (ARGB override)
  isDeleted, deletedDate?

AppList (lib/src/models/app_list.dart)
  name, folderId?, sortOrder
  color? (ARGB accent), iconId?, iconColor? (ARGB override)
  listType: ListType                 ← 'tasks' | 'birthdays' | 'shopping'
  isDeleted, deletedDate?

ListSection (lib/src/models/list_section.dart)   ← NOT an AppItem
  id, listId, name, sortOrder, isCollapsed, creationDate

NoteFolder (lib/src/models/note_folder.dart)
  name, parentFolderId?, sortOrder, iconId?
  isDeleted, deletedDate?

Note (lib/src/models/note.dart)                  ← NOT an AppItem
  id, title, content, folderId?
  creationDate, modifiedDate, sortOrder
  isDeleted, deletedDate?
  copyWith({preserveModifiedDate})   ← skip bumping modifiedDate on moves/reorder

Event (lib/src/models/event.dart)                ← calendar entity
  id, title, note?, date, doTime?, duration?, reminderOffsets
  isDeleted, deletedDate?

Contact (lib/src/models/contact.dart)            ← belongs to a Birthdays list
  id, name, note?, listId (REQUIRED)
  birthMonth, birthDay, birthYear?   ← year optional → no age shown
  isCompletable, isCompleted, completionDate?
  reminderOffsets, creationDate, sortOrder
  isDeleted, deletedDate?

Tag (lib/src/models/tag.dart)
  id, name (case-insensitively unique), color? (ARGB), creationDate

Recurrence (lib/src/models/recurrence.dart)
  type ('daily'|'weekly'|'monthly'|'yearly'), interval, weekdays? (weekly)
  nextAfter(DateTime) → DateTime     ← month-length edge cases handled
  JSON-encoded into Task.recurrence

RoutineEntry (lib/src/models/routine_entry.dart) ← per-day progress
  id, routineId, date (midnight), amount (cumulative for the day)

RemoteEvent (lib/src/integrations/google/remote_event.dart) ← in-memory only,
  never persisted; mirrors Event + Google fields (googleEventId, calendarId,
  calendarColor, htmlLink, etag, isReadOnly, recurringEventId)
```

`Task.copyWith` accepts clear-flags (`clearNote`, `clearDueDate`, `clearDoTime`, `clearDuration`, `clearListId`, `clearDeletedDate`, `clearCompletionDate`, `clearParentTaskId`, `clearRecurrence`, `clearSectionId`). `AppFolder` / `AppList` / `Contact` / `Event` / `Note` follow the same pattern. Item spacing: task rows use `vertical: 7` padding; list/folder rows use `vertical: 9`.

### Soft-delete pattern

**All user-facing deletes are soft-deletes.** Nothing is removed from the database immediately — items get `isDeleted = true` and `deletedDate = now`, then move into a Trash in-memory list inside the controller. DB queries for active items filter `WHERE isDeleted = 0`.

- `TaskController.deleteTask(id)` — soft-deletes the task *and its entire subtask subtree*; all share one `deletedDate`.
- `TaskController.deleteTasksForList(listId)` — bulk soft-delete (called when a list is trashed).
- `FolderController.deleteList(id)` — soft-deletes the list.
- `FolderController.deleteFolderDeep(id, onDeleteList)` — recursively soft-deletes the folder, all nested subfolders, all their lists; `onDeleteList` is `TaskController.deleteTasksForList`. All items in the same deep-delete share one `deletedDate` timestamp.
- `NoteController.deleteFolderDeep(id)` — analogous (no callback; notes have no cross-controller dependency).
- `ContactController.deleteContact(id)` — soft-delete.
- Swipe-to-delete on lists/folders/notes shows a `confirmMoveToTrash` `CupertinoAlertDialog`; `Dismissible.confirmDismiss` bounces back on cancel.
- **Bulk restore by `deletedDate`**: `restoreAt(DateTime)` exists on `TaskController`, `FolderController`, `NoteController`, `ContactController`. The shared timestamp from a deep-delete lets the Undo banner restore everything atomically.

Permanent deletion (from Trash) hard-deletes the row:
- `TaskController.permanentlyDeleteTask(id)` / `permanentlyDeleteAllTrashed()`
- `FolderController.permanentlyDeleteList(id)` / `permanentlyDeleteFolder(id)` / `permanentlyDeleteAllTrashed()`
- `NoteController.permanentlyDeleteNote(id)` / `permanentlyDeleteFolder(id)` / `permanentlyDeleteAllTrashed()`
- `ContactController.permanentlyDeleteContact(id)` / `permanentlyDeleteAllTrashed()`
- `EventController.permanentlyDeleteEvent(id)` (events have no soft-delete path; calendar delete is immediate but routed through `UndoController` for revert).

### Custom icon storage (`lib/src/folders/folder_icon_picker.dart`)

Custom photo icons for folders, lists, and routines are stored as **relative paths** (`icons/<timestamp>.<ext>`) under the app's documents directory. Critical for iOS — absolute paths break after every reinstall because the container UUID changes. (Routines reuse this storage; `RoutineCircleIcon` resolves the same `icons/…` paths.)

- `initFolderIconService()` — called once in `main.dart` before `runApp`; caches `getApplicationDocumentsDirectory()` so path resolution is synchronous during widget builds.
- `isCustomIconId(iconId)` — `true` for relative paths (`icons/…`) and legacy absolute paths (`/…`).
- `resolveCustomIconPath(iconId)` — runtime absolute path; handles new relative + legacy absolute (graceful fallback).
- `buildFolderItemIcon(iconId, isFolder)` — synchronous widget builder; falls back to the default PNG on error.
- Backups inline icon bytes as base64 in a top-level `customIcons` map keyed by relative path; on import they're written back to `<docsDir>/icons/`.

### Database (`lib/src/database/database_service.dart`)

Single `DatabaseService` class, lazy-opens its DB file (`dbName`, default `planom.db`) via sqflite. Current version: **25**. One `DatabaseService` instance per file — never open the same file with two handles (the default space reuses the global handle; see Spaces).

Migration history:
| Version | Changes |
|---------|---------|
| v2  | `tasks.dueDate INTEGER` |
| v3  | `tasks.listId TEXT` + `folders` + `app_lists` tables |
| v4  | `tasks.doTime INTEGER`; `folders` / `app_lists` (IF NOT EXISTS) |
| v5  | `note_folders` + `notes` tables |
| v6  | `routines` + `routine_entries` tables |
| v7  | priority + sortOrder columns on tasks, folders, app_lists, note_folders, notes |
| v8  | `app_lists.color INTEGER` |
| v9  | `folders.iconId`, `app_lists.iconId` |
| v10 | `note_folders.iconId` |
| v11 | `isDeleted`/`deletedDate` on tasks, folders, app_lists |
| v12 | `isDeleted`/`deletedDate` on note_folders, notes |
| v13 | `tasks.completionDate INTEGER` |
| v14 | `app_settings` table (TEXT key PK, TEXT value) |
| v15 | `events` table (calendar entity, separate from tasks) |
| v16 | `tasks.duration INTEGER` |
| v17 | `tasks.reminderOffsets TEXT`, `events.reminderOffsets TEXT` |
| v18 | `tasks.parentTaskId TEXT` (subtasks) |
| v19 | `tasks.tagIds TEXT` + `tags` table |
| v20 | `tasks.recurrence TEXT` |
| v21 | FTS5 virtual tables (`tasks_fts`, `notes_fts`, `events_fts`) + sync triggers + one-shot backfill |
| v22 | `folders.iconColor INTEGER`, `app_lists.iconColor INTEGER` (per-icon color override) |
| v23 | `app_lists.listType TEXT NOT NULL DEFAULT 'tasks'` |
| v24 | Birthday columns added to `tasks` (transitional); `tasks.sectionId TEXT`; `list_sections` table |
| v25 | Migrates birthday rows out of `tasks` into a new `contacts` table; recreates `tasks` without birthday columns (SQLite < 3.35 can't drop columns); re-creates `tasks_*` FTS triggers after the rename |
| v26 | Routines refactor: drops + recreates `routines` (now `daysAfterComplete` / `autoReset`-free; `frequencyType` defaults `'daily'`) and `routine_entries` clean. Old routine data is intentionally discarded (sanctioned by the refactor). Legacy backups still import — `BackupService` normalises routine rows through `Routine.fromMap`/`toMap` to drop the removed columns |
| v27 | `routines.weekdays TEXT` — re-introduces a weekday schedule: `specific_days` routines store selected weekdays (0=Mon … 6=Sun) as a comma-joined string; `daily` leaves it null |
| v28 | `routines.startDate INTEGER`, `routines.intervalDays INTEGER`, `routines.waitForCompletion INTEGER NOT NULL DEFAULT 0`, `routines.reminders TEXT` — start date, `interval` ("every N days") scheduling with optional wait-for-completion, and per-routine reminders (JSON) |

When adding new tables/columns, bump `_dbVersion` and add an `onUpgrade` branch.

**Full-text search (FTS5)** — `DatabaseService.searchAll(query, {limit = 50}) → SearchResults` returns id sets keyed by source table. Each token is wrapped in `"…"*` (with internal quotes doubled), so the user gets implicit AND prefix matching without exposed FTS5 syntax. Triggers keep `tasks_fts` / `notes_fts` / `events_fts` in sync; `_backfillFts` populates pre-existing rows during the v21 upgrade.

**`app_settings` keys** (all stored as strings):
- `tab_<i>_visible` (i = 0..4) — per-tab visibility booleans
- `tab_order` — comma-separated ordered list of logical tab indices
- `default_tab` — logical index `'0'..'4'` or sentinel `'last'` (`kLastOpenedTab`) to restore the last-used tab on launch
- `last_tab` — last logical tab opened (persisted for `default_tab = last`)
- `accent_color`, `completion_color` — ARGB int as decimal string
- `font` — Google Fonts camelCase key or `'__system__'`
- `locale` — BCP-47 language code (`en`, `uk`, `es`, `fr`, `de`, `it`, `pt`, `ru`, `zh`, `ja`)
- `task_field_prefs` — JSON-serialised `TaskFieldPrefs`
- `auth_type`, `auth_hash`, `auth_salt`, `auth_biometric` — passcode + biometric flag (owned by `SecurityService.authSettingKeys`; **excluded from backup export and never overwritten on import**)
- `gcal_email`, `gcal_selected_calendar_ids` (JSON list), `gcal_default_calendar_id`, `gcal_last_sync_at`, `gcal_synctoken_<calendarId>` — Google Calendar state (owned by `GoogleCalendarController`; **excluded from backups** via `isReservedKey`)
- `sync_backend` — selected `SyncBackend` (owned by `SyncController`)

**Backup import is atomic**: `BackupService` parses/validates the whole payload first, then `DatabaseService.replaceAllData` clears + re-inserts every table inside one transaction (rolls back on any error, so a corrupt or partial backup can't destroy existing data). Backups currently cover only the **active** space (multi-space backup is a known follow-up).

Other useful methods:
- `getTasks()` / `getTrashedTasks()` — active vs trashed
- `softDeleteTask`, `restoreTask`, `permanentlyDeleteTask` (+ equivalents for folders, lists, note_folders, notes, contacts)
- `clearTrashed*` — bulk hard-delete (`isDeleted = 1` rows), used by "Empty Trash"
- `resetUserData()` — wipes all user tables (used by "Reset Data" in Settings → Data)
- `replaceAllData(tables)` — atomic clear+restore for backup import / sync pull
- `_allTables` — canonical list of user tables used by reset/restore (note: tables are deleted in FK-friendly order)

### Controllers

Every controller is a `ChangeNotifier`. They're constructed in `main.dart` (global) or by `SpaceManager` (per-space), then passed through `MyApp` → `HomeShell` → views via plain constructor injection.

**`TaskController`** (`lib/src/tasks/task_controller.dart`)
- Owns `_tasks`, `_trashedTasks`, `_tags` (flat global namespace).
- Smart-list getters (all exclude subtasks, i.e. `parentTaskId == null`): `inboxTasks`, `todayTasks`, `tomorrowTasks`, `upcomingTasks`, `allTasks`, `allCompletedTasks`.
- Scoped queries: `tasksForList(listId)`, `tasksForListSection(listId, sectionId?)` (active only — completed roll up to the implicit "Completed" virtual section at the bottom), `completedTasksForList(listId)`, `tasksForDate(date)`, `subtasksOf(parentId)` (oldest first).
- Sorting: `setSortOrder(TaskSortOrder)` — `defaultOrder` | `creationDate` | `name` | `priority` | `dateTime`. Only `defaultOrder` enables drag-reorder. Smart lists apply the chosen sort then move completed to the end (oldest completion first).
- Mutations: `addTask`, `updateTask`, `toggleCompleted`, `moveTaskToSection`, `reorderTasks({listId, sectionId, oldIndex, newIndex})`, `reorderTaskBefore(...)` (long-press drag, can change section / list).
- Recurrence: `toggleCompleted` checks `Recurrence.parse(task.recurrence)` — on completion of a recurring task, advances `dueDate` to `Recurrence.nextAfter(...)` and reschedules reminders **instead of** marking it done.
- Tags: `tagById`, `tagsForTask`, `tasksWithTag`, `addOrGetTag(name, {color})` (case-insensitive dedup), `updateTag`, `deleteTag` (also strips the id from every referencing task).
- Reminders: `scheduleTaskReminders(task)` / `cancelTaskReminders(taskId)` via `NotificationService` — toggling complete cancels, un-completing reschedules, delete cancels.
- Trash: `deleteTask` (soft, recursive into subtasks), `restoreTask(id, targetListId)`, `restoreAt(deletedDate)`, `permanentlyDeleteTask`, `permanentlyDeleteAllTrashed`.
- iOS app badge: `_updateBadge()` writes `todayUncompletedCount` to `flutter_app_badger`. Overdue uncompleted tasks roll into `todayTasks` (any `dueDate ≤ today`), so the badge counts them automatically. No-op on platforms where `supportsAppBadge == false`.

**`FolderController`** (`lib/src/folders/folder_controller.dart`)
- Owns `_folders`, `_lists`, `_sections`, `_trashedFolders`, `_trashedLists`.
- Folders/lists: `foldersIn(parentId?)`, `listsIn(folderId?)`, `folderById`, `listById`, `listIdsInRecursive(folderId)` (iterative walk).
- Sections (new): `sectionsForList(listId)`, `sectionById`, `addSection`, `updateSection`, `deleteSection`, `reorderSections`, `toggleSectionCollapsed` (collapse state persisted).
- Reorder: `reorderFolders(parentId?, old, new)`, `reorderLists(folderId?, old, new)`, plus long-press-drag variants `reorderFolderBefore` / `reorderListBefore` that can also move an item between parent folders.
- Trash: `deleteList`, `deleteFolderDeep(id, onDeleteList)` (recursive — task controller cascades), `restoreList`, `restoreFolder`, `restoreAt(deletedDate)` (bulk), `permanentlyDeleteList`, `permanentlyDeleteFolder`, `permanentlyDeleteAllTrashed`.

**`NoteController`** (`lib/src/notes/note_controller.dart`)
- Owns `_notes`, `_folders`, `_trashedNotes`, `_trashedFolders`.
- Read: `allNotes`, `notesIn(folderId)` (sortOrder then modifiedDate desc), `foldersIn(parentId)`.
- Mutate: `addNote`, `updateNote`, `moveNote` (preserves `modifiedDate`), `deleteNote`, `restoreNote`, `permanentlyDeleteNote`, `permanentlyDeleteAllTrashed`.
- Folders: `addFolder`, `updateFolder`, `deleteFolderDeep(id)` (recursive — returns the shared `deletedDate`), `restoreFolder`, `restoreAt(deletedDate)`.
- Reorder: `reorderNoteFolders`, `reorderNotes`, plus before-style `reorderNoteFolderBefore` / `reorderNoteBefore` that can also change `folderId` (note reorder preserves `modifiedDate`).

**`ContactController`** (`lib/src/contacts/contact_controller.dart`)
- Owns `_contacts`, `_trashedContacts`.
- `contactsForList(listId)` — sorted by creation; `contactsForDate(date)` matches by month+day only (used for calendar birthday chips).
- `addContact`, `updateContact`, `toggleCompleted`, `deleteContact`, `restoreContact(id, {targetListId})`, `restoreAt(deletedDate)`, `permanentlyDeleteContact`, `permanentlyDeleteAllTrashed`.
- Date math: Feb 29 births fall back to Feb 28 in non-leap years (`_safeDate`).

**`RoutineController`** (`lib/src/routines/routine_controller.dart`)
- **Per-day history.** Each calendar day is tracked independently by a `RoutineEntry` row, so a routine auto-resets every day and the full history is preserved (revisit/edit any past day; future days are blocked). All progress queries take an explicit `date`.
- `routinesForDate(date)` — routines from their `startFloor` (`startDate ?? creationDate`) onward, filtered by schedule: `daily` always, `specific_days` on its weekdays (Dart `weekday - 1` → 0=Mon … 6=Sun), `interval` per the rules below. Day arithmetic uses `_epochDay` (UTC midnight) to stay DST-safe. `todayRoutines` = `routinesForDate(now)`.
- **Interval scheduling.** Fixed-grid (`waitForCompletion = false`): appears when `(epochDay(day) - epochDay(start)) % intervalDays == 0`. Wait-for-completion: `intervalOccurrences(r)` reconstructs the occurrence sequence from completion history (each completion opens the next occurrence at `completionDate + intervalDays`); the open occurrence shows from its scheduled date **through today** (overdue carry-forward), and `openOccurrenceDate` / `isOverdueOn(r, date)` drive the UI. Completing an overdue occurrence on its original day vs the viewed day is the "record original vs shift" choice (the UI prompts for `achieve_all`).
- `entryForDate` / `progressForDate` / `isCompletedOnDate(routine, date)` (+ `entryForToday` / `todayProgress` / `isTodayCompleted` convenience wrappers). `goalFor(routine)` = `1` for `achieve_all`, else `goalAmount`.
- `recordProgress(routine, [date])` — `achieve_all` toggles 0↔1; `certain_amount` adds `recordAmount` and wraps back to 0 once the goal is reached (so a day can be un-completed/corrected). Defaults to today when `date` omitted. Also (re)schedules reminders; `afterEach` reminders are anchored to the tap.
- **Reminders.** `reminderFireTimes(r)` computes concrete future fire times for `time` / `spread` reminders across a rolling horizon of active days; `_syncReminders` hands them to `NotificationService.scheduleRoutineReminders`. Called on `load`/`add`/`update`/`recordProgress`; `delete` cancels.

**`EventController`** (`lib/src/calendar/event_controller.dart`)
- Owns local `_events`; mirrors `TaskController` shape but without subtasks/tags.
- `eventsForDate(date)`, `addEvent`, `updateEvent`, `deleteEvent` (immediate hard-delete from DB but `UndoController` lets the user revert by re-inserting).

**`SettingsController`** (`lib/src/settings/settings_controller.dart`)
- Loads state from `app_settings` rows + `SettingsService` (`SharedPreferences` for `ThemeMode`) + `SmartListPrefs.load()` (separate JSON file in docs dir).
- State: `themeMode`, `locale`, `fontKey` (Google Fonts key or `kSystemFontKey`), `accentColor`, `completionColor`, `smartListPrefs`, `taskFieldPrefs`, `_tabVisibility` (map 0..4), `_tabOrder` (`List<int>` of length 5, perm of [0..4]), `_defaultTab` (`'0'..'4'` or `kLastOpenedTab`), `_lastOpenedTab` (int).
- `colorRevision` (`ValueNotifier<int>`): bumped on accent / completion color change **instead of** `notifyListeners()`. The `CupertinoApp` rebuild path is wrapped in `ValueListenableBuilder(colorRevision)` so color changes rebuild only the content subtree, not the whole app (theme/locale/font). Color-sensitive widgets (e.g. `AppearanceView`) listen to `Listenable.merge([controller, colorRevision])`.
- `resolveInitialTab(visible)` — picks the logical tab to show on launch; falls back to the first visible tab if the configured choice is hidden.
- Mutations (each persists + notifies/bumps): `setTabVisible(i, bool)`, `updateTabOrder(List<int>)` (validated: length 5, no dupes), `updateDefaultTab`, `setLastOpenedTab(i)` (no notify — UI doesn't react live), `updateThemeMode`, `updateLocale`, `updateFontKey`, `updateAccentColor`, `updateCompletionColor`, `updateHideTabLabels`, `updateShowAddFolderButton` / `updateShowNotesAddFolderButton`, `updateNotesUseMarkdown`, `updateTaskFieldPrefs(TaskFieldPrefs)`, `updateSmartListVisibility(key, SmartListVisibility)`, `importSmartListPrefs(map)` (used by backup import).

**`BackupService`** (`lib/src/settings/backup_service.dart`)
- Not a `ChangeNotifier`. Created by `SpaceManager` per active space and passed through `MyApp` → `HomeShell` → `SettingsView`.
- `buildPayloadJson()` — serialises every table (active + trashed) + custom icon bytes (base64) + `smart_list_prefs`; filters `auth_*` and `gcal_*` keys from `app_settings`. Folder / list / note-folder / **routine** `iconId`s are run through `_inlineIcons` so custom photos travel with the backup. Returns the canonical payload string.
- `exportBackup({passphrase?})` — generates the payload, optionally encrypts (`backup_crypto.encryptBackup`), writes a `planom_backup_YYYY-MM-DD.planom` file to temp, and either shares (mobile/macOS) or opens a Save-As dialog (Linux/Windows).
- `importBackup({passphraseProvider?})` — picks a file, detects encryption via `isEncryptedBackup`, calls the provider if a passphrase is required, then `_applyImportedPayload`.
- `importPayloadJson(plain)` — sync's entry point (no UI / file picker).
- `_applyImportedPayload(map)` — preserves device `auth_*` and `gcal_*` keys, restores icon files, calls `replaceAllData`, reloads controllers, re-applies smart-list prefs.
- `hardReset()` — wipes all user data via `resetUserData()` and reloads controllers (used by Settings → Data → Reset).
- Backup format: JSON, `.planom` extension. v1 = plaintext, v2 = `BackupCrypto` envelope. Top-level keys: `version`, `exportDate`, `customIcons`, `tasks`, `tags`, `folders`, `app_lists`, `note_folders`, `notes`, `routines`, `routine_entries`, `events`, `list_sections`, `contacts`, `app_settings`, `smart_list_prefs`.

**`SyncController`** (`lib/src/sync/sync_controller.dart`) — see Sync.

**`GoogleCalendarController`** (`lib/src/integrations/google/google_calendar_controller.dart`) — see Google Calendar.

**`PlanomMcpServer`** (`lib/src/mcp/mcp_server.dart`) — see MCP server.

### Spaces (`lib/src/spaces/`)

`SpaceManager` (`ChangeNotifier`, provided via `SpaceManagerProvider` `InheritedWidget`) lets the user keep multiple independent data sets ("spaces"). Each space is a separate DB file; the **default** space reuses the global `planom.db` handle (created in `main.dart` and also used by `SettingsController`/`SecurityService`/`GoogleCalendarController`), while non-default spaces use `planom_<id>.db`.

- Metadata: `Space` list + active id stored in `spaces.json` in the docs dir; loaded with a corrupt-file fallback and saved atomically (temp file + rename).
- On `switchSpace`, the previous (non-default) DB is closed and a fresh set of per-space controllers (`TaskController`, `FolderController`, `NoteController`, `RoutineController`, `EventController`, `ContactController`, `BackupService`) is built for the new space. `main.dart` re-keys `MyApp` by `activeSpaceId` to force a clean rebuild (fresh Navigator stacks, scroll positions, etc.).
- `addSpace`, `renameSpace`, `switchSpace`, `deleteSpace` (refuses the default/last space; switches away first if the deleted space is active; deletes the DB file).
- **Global** prefs (appearance/font/locale/tab visibility), the passcode, Google Calendar connection state, and sync backend selection all live in the global `planom.db`'s `app_settings`, **not** per space.

### Security / app lock (`lib/src/security/`)

`SecurityService` (`security_service.dart`) stores an optional passcode in `app_settings`:
- `auth_type`: `none` | `pin4` | `pin5` | `pin6` | `pin7` | `pin8` | `custom`
- `auth_hash`: PBKDF2/HMAC-SHA256 (100 000 iterations), base64
- `auth_salt`: 16 random bytes, base64
- `auth_biometric`: `'true'`/`'false'` — whether Face ID / Touch ID / Windows Hello is enabled. The flag persists even if biometric becomes unavailable on the device.

Legacy unsalted SHA-256 hashes verify once and are transparently upgraded to the salted PBKDF2 form on first successful verification.

API: `load`, `isBiometricAvailable` (calls `local_auth`; returns false on macOS/Linux), `authenticateBiometric(reason)`, `setPassword(password, type)`, `removePassword`, `verify(password)`, `setBiometricEnabled(bool)`.

`_SecurityGate` in `app.dart` shows `LockScreen` when locked: on launch + on resume from background (driven by `WidgetsBindingObserver.didChangeAppLifecycleState`).

`authSettingKeys` — the set of passcode keys backups must exclude on export and never overwrite on import.

### Notifications (`lib/src/notifications/`)

`NotificationService` (singleton) wraps `flutter_local_notifications` + `timezone`. Tasks/events/contacts carry `reminderOffsets` (minutes relative to the due/event/birthday time). Routines instead carry `RoutineReminder`s (clock times / spreads / after-each delays); `RoutineController` resolves them to absolute fire times and calls `scheduleRoutineReminders(routineId, title, fireTimes)` / `cancelRoutineReminders(routineId)`.

- Slot-based IDs: `_notifSlot(itemId, slotIndex)` over `0.._maxSlots-1` (20). Scheduling and cancellation **both** use the same slot formula — they must stay in sync.
- `TaskController.toggleCompleted` cancels reminders on complete and reschedules on un-complete; delete cancels. Recurrence-driven advance also reschedules.
- `initTimezone()` matches the IANA zone by current UTC offset (known DST limitation; `flutter_timezone` is the documented follow-up).
- No-ops on platforms where `supportsLocalNotifications == false` (Android/Linux/Windows today).

### Sync (`lib/src/sync/`) — new

End-to-end optional backup-style sync. **No conflict resolution** — pull always replaces all local data; the UI requires explicit confirmation.

`SyncController` (`sync_controller.dart`) — top-level orchestrator. Backend-agnostic; uses an abstract `SyncProvider` and `BackupService` for payload generation.
- State: `SyncSnapshot { backend, status, lastSyncAt?, lastError? }`.
- API: `load`, `setBackend(SyncBackend)`, `setPassphrase`, `hasPassphrase`, `clearPassphrase`, `pushNow`, `pullNow`, `disableAndWipeRemote`.
- **Push**: `BackupService.buildPayloadJson` → optional `encryptBackup(plain, passphrase)` → `provider.push(bytes)`.
- **Pull**: `provider.pull()` → detect encryption via `isEncryptedBackup` → optional `decryptBackup(envelope, passphrase)` → `BackupService.importPayloadJson(plain)`. Returns `false` if remote is empty.

`SyncState` (`sync_state.dart`):
- `SyncBackend { none, icloud, planom, custom }` — only `none` and `icloud` are wired today; `planom` (hosted) and `custom` (BYO server) are reserved.
- `SyncStatus { idle, pushing, pulling, succeeded, failed, notConfigured, passphraseRequired, notAvailable }`.

`SyncSecrets` (`sync_secrets.dart`) — passphrase in OS-secure storage (`flutter_secure_storage`: iOS Keychain, Android Keystore, etc.). **Not** in the DB, so it's never exported.

`ICloudSyncProvider` (`icloud_sync_provider.dart`) — wraps `icloud_storage` to write a single `planom.sync.enc` file to the iCloud Documents container. Requires the iCloud capability + container `iCloud.app.planom` set up in Xcode; if entitlements are missing or the user isn't signed into iCloud, `isConfigured()` returns false and the UI shows a "setup required" state. Only on iOS / macOS — `isAvailable()` is false elsewhere.

**Encryption** (`lib/src/settings/backup_crypto.dart`):
- AES-256-GCM, PBKDF2-SHA256 (100 000 iterations), 16-byte salt, 12-byte nonce per encryption.
- Envelope JSON (v2): `{ version, encryption, iterations, salt, nonce, ciphertext }`.
- Same envelope is used by both backup export and sync push — `decryptBackup` accepts either.
- Passphrase changes are independent of backend selection. Devices with no passphrase can still pull plaintext payloads; devices with a passphrase get `passphraseRequired` if the remote is plaintext or the key is wrong.

### MCP server (`lib/src/mcp/`) — new

Transport-agnostic JSON-RPC 2.0 server exposing the app's core data via the Model Context Protocol. The repo ships **only the protocol layer** — no stdio/websocket/HTTP transport is bundled; an embedder wires it up however it needs to.

- `mcp_types.dart` — `McpRequest`, `McpResponse`, `McpError`, `McpException`, `McpTool`, `McpServerInfo`, `McpToolResult`.
- `mcp_dispatcher.dart` — stateless JSON-RPC router; handles `initialize`, `tools/list`, `tools/call`; catches `McpException` and returns `isError: true` responses.
- `mcp_tools.dart` — const list of ~23 `McpTool` definitions with JSON-Schema input descriptors.
- `mcp_server.dart` — `PlanomMcpServer(SpaceManager)` facade. `handle(McpRequest) → McpResponse` or `handleJson(String) → String`. All tools route through the **active** space's controllers.

Tools cover: tasks (list / create / update / complete / delete / restore with scopes `inbox | today | tomorrow | upcoming | completed | trash | list | all`), lists/folders (list / create), notes (list / create / update / delete), routines (list / record progress), events (list with date range filter), spaces (list / switch), and search (naive substring contains across task title+note and note content — **not** FTS5). All dates are ISO-8601 strings; times are minutes-since-midnight ints.

### App shell (`lib/src/home_shell.dart`)

`HomeShell` is a `StatefulWidget` managing up to **5 logical tabs**: Tasks(0) always-on, then Notes(1) / Calendar(2) / Routines(3) / Settings(4) — each toggleable in Settings → Tab Bar. Layout adapts:

- **Wide layout** (`PlatformCapabilities.isDesktop` OR window width ≥ 700 px) → `_WideLayout` with a persistent left sidebar.
- **Single visible tab** → no tab bar at all; just `CupertinoTabView`.
- **Otherwise** → `CupertinoTabScaffold` + `CupertinoTabBar` at the bottom.

The sidebar/tab-bar **order** is user-configurable in Settings → Tab Bar (`SettingsController.tabOrder`); visibility is independent. A "Default tab on launch" preference (`SettingsController.defaultTab`) selects one of `'0'..'4'` or `'last'` (`kLastOpenedTab` — restore the last opened tab).

Key state:
- `_navigatorKeys`: per-tab `GlobalKey<NavigatorState>` — used to pop-to-root on same-tab re-tap.
- `_depthObservers`: per-tab `_DepthObserver extends NavigatorObserver` — tracks push/pop depth AND counts routes matching `trackedRouteName`.
- `_showPlusButton`: `ValueNotifier<bool>` toggled by `_depthObservers`; passed to `ValueListenableBuilder` that wraps the `Positioned` button.
- `_activeListId` / `_activeDueDate`: `ValueNotifier<T?>` that child views set to pre-fill the task creation sheet's list and date.
- `_tasksCollapseSignal` / `_notesCollapseSignal`: `ValueNotifier<int>` bumped when the Tasks/Notes tab is re-tapped, used by views to collapse expanded folders.
- `_calendarResetSignal`: `ValueNotifier<int>` bumped when Calendar tab is re-tapped, causing `CalendarView` to scroll back to current month.
- `_lastTabIndex`: last tapped tab (logical index) — detects same-tab re-tap.
- `_globalSettingsOpen` + `_globalSettingsRoute`: `ValueNotifier<bool>` + `Route?` for the **global Settings overlay** (see below).
- `_plusDragController`: provides `PlusDragScope` so any descendant can register drop targets (see Plus-button drag pattern).
- `_undoController`: provides `UndoScope` so any deletion site can show an Undo banner.

**Plus button visibility rules:**
- Tab 0 (Tasks): shown unless a `TaskDetailView` is on the stack (`_depthObservers[0].trackedCount == 0`). Visible on TasksView, smart lists, FolderView, ListTaskView at any nesting depth; hidden only inside the task edit screen.
- Tab 1 (Notes): always hidden — Notes manages its own UI.
- Tabs 2 & 3 (Calendar / Routines): hidden when depth > 1.
- Tab 4 (Settings): always hidden.
- `_DepthObserver` accepts an optional `trackedRouteName`; tab 0's observer tracks `'task_detail'`. All `TaskDetailView` pushes use `RouteSettings(name: TaskDetailView.routeName)`.

**Plus button action (`_onPlusPressed`):**
- Tab 3 (Routines): pushes `RoutineCreationView` on the Routines tab navigator.
- Tab 2 (Calendar) with an active selected day: opens a Task vs Event picker via `showSelectionMenu`.
- If the active list is a Birthdays list: opens `showContactCreationSheet` instead of the task sheet.
- Otherwise: shows `TaskCreationSheet` modal (root navigator) seeded with `_activeListId` / `_activeDueDate`.

**Global Settings overlay**: when the Settings tab is hidden, every other tab's root view exposes a ⋯ button that calls `HomeShell.openGlobalSettings(context)`. This pushes `SettingsView` on the **root navigator** (above the tab bar) and flips `_globalSettingsOpen.value = true`. While open, the tab bar repaints every tab's active icon/label in `secondaryLabel` so no tab reads as "selected". `_reopenSettingsFullScreen` is the related path used when the Settings tab is **hidden while the user is in it**, so the screen stays put.

### Navigation

- `MyApp.onGenerateRoute` in `app.dart` returns `FastRoute` instances. The only top-level destination is `HomeShell` (wrapped in `_SecurityGate` + `ValueListenableBuilder(colorRevision)`).
- In-tab navigation uses `Navigator.of(context).push(FastRoute(...))` directly — never bare `CupertinoPageRoute`.
- Settings is normally a dedicated tab (logical index 4); the **global overlay** above is the fallback when that tab is hidden.

### Tasks feature (`lib/src/tasks/`)

| File | Purpose |
|------|---------|
| `tasks_view.dart` | Tab root; smart-list rows + reorderable folders/lists. Smart-list visibility driven by `SmartListPrefs` (`show` / `showIfNotEmpty` / `hidden`) per list (Today, Tomorrow, Upcoming, All Tasks, Completed, Trash). Supports Plus-button drop targets on every row. Multi-select via `SelectableTaskListShell`. |
| `inbox_view.dart` | Active tasks with `listId = null`; swipe-to-delete → Trash via `UndoController`. |
| `today_view.dart` | Active tasks where `dueDate ≤ today` (i.e. today + overdue). Overdue tasks show date in red. Sets `activeDueDate` so `+` pre-fills today. |
| `tomorrow_view.dart` | Active tasks where `dueDate` is exactly tomorrow. Sets `activeDueDate` so `+` pre-fills tomorrow. |
| `upcoming_view.dart` | Tasks with `dueDate > today`, grouped by date header. |
| `all_tasks_view.dart` | Read-only union of all incomplete active tasks across every scope. Plus button defaults to Inbox. |
| `completed_view.dart` | All non-trashed completed tasks across every scope; swipe-to-delete → Trash. |
| `trash_view.dart` | All trashed tasks + lists + folders, sorted by `deletedDate DESC`; tap task → `TaskDetailView` (read-only context); swipe right = Put Back (blue, shows restore destination); swipe left = Delete Permanently (red, confirms); ⋯ nav-bar → Empty Trash. |
| `task_detail_view.dart` | Edit screen with autosave (debounced). Subtask list with inline "Add Subtask". Markdown preview/edit toggle for notes when `taskFieldPrefs.useMarkdown`. Field rows driven by `TaskFieldPrefs`. `routeName = 'task_detail'`. |
| `task_creation_sheet.dart` | Modal bottom sheet (root navigator); hide-disabled-fields driven by `TaskFieldPrefs`. Accepts `initialListId`, `initialDueDate`, `initialSectionId`. |
| `selectable_task_list_shell.dart` | Multi-select scaffold reused by every smart-list / list view: nav-bar ⋯ → "Select" toggles selection mode, bottom `SelectionToolbar` exposes batch delete/toggle/set-date/move-to-list. |
| `tag_picker_sheet.dart` | Multi-select tag UI with inline "Create" on a brand-new name. |
| `recurrence_picker.dart` | Modal picker for repeat (daily/weekly/monthly/yearly + interval; basic weekly-weekday support). |
| `task_field_prefs.dart` | `TaskFieldPrefs` — bitfield-ish of optional fields shown in detail/creation (`showPriority`, `showDate`, `showRepeat`, `showList`, `showDuration`, `showTags`, `showReminders`, `showListCount`, `useMarkdown`, `folderCounterMode`: `hidden` / `directOnly` / `recursive`). Persisted JSON in `app_settings`. |
| `calendar_date_picker.dart` | Date+time picker; `formatTaskDate` / `formatDoTime` helpers; returns `(DateTime?, int?)?` — outer null = barrier dismiss, `(null, null)` = No Date, `(date, time?)` = selection. |
| `task_controller.dart` | (see Controllers above) |
| `task_row.dart` | `TaskRow` + `TaskDeleteBackground` + `taskProxyDecorator` shared across list views. |

**Ordering**: `inboxTasks`, `tasksForList`, `todayTasks` all pass through `_completedLast()` — incomplete first, completed at the bottom. Unchecking restores to the incomplete group, not the original position.

**Smart list visibility rules** in `tasks_view.dart` are driven by `SmartListVisibility` enum on each `SmartListPrefs` field: `show` always, `showIfNotEmpty` only when populated, `hidden` never.

**Dismissal pattern** for lists/folders: `Dismissible.confirmDismiss` → `confirmMoveToTrash` Cupertino dialog → `onDismissed` calls the appropriate soft-delete + `UndoController.show(...)` with a revert callback.

### Folders feature (`lib/src/folders/`)

| File | Purpose |
|------|---------|
| `folder_view.dart` | Subfolder/list browser; reorderable; swipe-to-delete with confirm; Plus drop targets; long-press → `showSelectionMenu` for edit/delete/move/icon. Plus-button drop on a folder row routes to `_handleDropOnFolder`. Hovering a folder row for 1.5 s while dragging auto-expands it (drag-traversal aid). |
| `list_task_view.dart` | Task list for a named list (or Birthdays — renders `ContactListView` instead); sets `activeListId` on enter/exit. Sections (collapsible) + implicit "Completed" virtual section at bottom. Long-press a section header → `showSelectionMenu` for rename/delete. Multi-select via `SelectableTaskListShell`. |
| `folder_controller.dart` | (see Controllers above) |
| `folder_icon_picker.dart` | Custom icon storage; `initFolderIconService`, `buildFolderItemIcon`, `isCustomIconId`, `resolveCustomIconPath`, `showFolderIconPickerSheet`. |
| `create_folder_list_sheet.dart` | `showCreateFolderListSheet` — bottom sheet to create a new folder or list (with `listType` chooser), optionally scoped to a parent folder. |
| `list_color_picker.dart` | Color swatch picker for list accent color. |
| `list_picker_sheet.dart` | Hierarchical folder/list browser (used by Task Detail's "List" row and the multi-select Move action). |
| `move_to_sheet.dart` | Similar picker for drag-drop destinations; excludes current and ancestor folders. |
| `section_name_sheet.dart` | Inline name dialog for adding / renaming sections within a list. |

### Notes feature (`lib/src/notes/`)

| File | Purpose |
|------|---------|
| `notes_view.dart` | Tab root; folder tree + flat notes at root + Trash row (visibility per `SmartListPrefs.notesTrash`). Plus drop targets on every folder row and on the empty root. Multi-select (`SelectableNoteListShell`-style) for batch delete / move. Long-press a note row to drag it between folders (drop targets highlight). |
| `note_folder_view.dart` | Inside-folder browser; same affordances as the root. |
| `note_detail_view.dart` | Full editor; markdown preview ↔ edit toggle (driven by `SmartListPrefs.notesUseMarkdown`). Autosave (3 s debounce + on blur / disposal). `MarkdownToolbar` shown above keyboard while editing. ⋯ menu → Move, Share, Info, Delete. `routeName = NoteDetailView.routeName`. |
| `markdown_view.dart` | Read-only markdown renderer using `flutter_markdown`; intercepts `http`, `mailto`, `tel`, and custom schemes via `url_launcher`. |
| `markdown_toolbar.dart` | Keyboard accessory with **bold**, *italic*, ~~strike~~, `code`, [link](url) buttons — wraps selection or inserts at cursor. |
| `note_widgets.dart` | Shared row widgets: `NoteFolderRow`, `NoteRow` (first-line preview with lightweight inline-markdown stripping). |
| `note_share.dart` | `showNoteShareMenu` — exports current note as plain text, PDF (via `pdf` package), or PNG image (renders markdown to canvas), shares via `share_plus`. |
| `note_trash_view.dart` | Trashed notes + folders; same swipe-right / swipe-left pattern as task Trash. |
| `create_note_folder_sheet.dart` | Icon + name sheet for new note folders. |
| `note_controller.dart` | (see Controllers above) |

### Routines feature (`lib/src/routines/`)

| File | Purpose |
|------|---------|
| `routine_icons.dart` | `kRoutineIconPresets` — 16 `(iconId, colorARGB)` preset combos; `routineIconData(iconId)` maps string keys to `CupertinoIcons`; `RoutineCircleIcon` renders a circular icon (custom photo clipped to circle, or tinted SF-symbol) with optional `dimmed` / `showCheck`. |
| `routine_controller.dart` | (see Controllers above) |
| `routine_creation_view.dart` | Full-screen `CupertinoPageScaffold` pushed on the Routines tab navigator; `showRoutineCreationView()` helper; reused for editing (`existing` param). Sections: name+icon, inline icon picker (preset grid + "choose photo" tile via `pickCustomIcon`), Frequency (segmented `Daily` / `Specific Days` / `Interval`; Specific Days reveals a Mon-first `_WeekdayPicker` that won't let you deselect the last day, Interval reveals an "Every N days" stepper + a "Wait for completion" switch) with a Start Date row, Goal (segmented + amount/unit/record fields), Reminders (add `time` / `spread` / `afterEach` reminders via clock/duration pickers; spread + afterEach are amount-goal only). |
| `routines_view.dart` | Tab root with two segments. **Day** segment: a `_DayNavigator` (‹ date ›, future blocked) over the routines for the selected day — tap a row to record progress for *that* day (history-editable); overdue interval+wait occurrences show a red "Overdue · date" subtitle and tapping prompts (record on original day vs complete now and shift); swipe-to-delete; long-press → edit/delete. **All** segment: every routine with a schedule subtitle (`Every day`, the weekday list, or `Every N days`) + goal; tap → edit. Custom photos render via `RoutineCircleIcon`. |

**Row layout**: 40 px circle icon (`RoutineCircleIcon`; dimmed + check overlay when `achieve_all` complete) · name (strikethrough when complete) · right-aligned `_ProgressBadge` for `certain_amount`. Row vertical padding is tightened to `8`.

**Unit picker**: `_UnitPickerSheet` offers presets (`ml`, `L`, `oz`, `count`, `minute`, `hour`, `km`, `mi`, `page`, `cup`, `lap`, `step`) plus a free-text "Custom…" option.

### Calendar feature (`lib/src/calendar/`)

`CalendarView` uses `CustomScrollView(center: _centerKey)` for true bidirectional infinite scroll (~600 months back / forward each ≈ 50 years).

- **Why `center:`** — anchors the viewport at the current month (scroll offset 0); past months build lazily only when the user scrolls up.
- **Layout**: `CupertinoPageScaffold` + standard nav bar showing `_visibleYear` (updated by scroll listener using `_avgMonthPx ≈ 481`) + fixed `_WeekdayHeader` (Mon–Sun) + `Expanded(CustomScrollView(...))`.
- **Reset signal**: `animateTo(0.0)` snaps back to the current month when the Calendar tab is re-tapped.
- **Day cells**: 88 px min height, up to 3 chips + `+N` overflow. Monday-first grid.
- **Pull-to-search**: when `db` + `noteController` are wired, the view is wrapped in `SearchPullScope` so a downward overscroll reveals a search bar that latches open at 30 % reveal and pushes `SearchView`.

**Chip rendering** uses a sealed `_ChipData` union — `task | event | remoteEvent | birthday`. Render order per day cell:
1. Local `Event` (blue)
2. `RemoteEvent` (Google calendar color, gray if past)
3. Birthday `Contact` (pink `0xFFFF2D55`)
4. Incomplete `Task` (list color or accent)
5. Completed `Task` (gray)

Past events are dimmed via `_eventIsPast` / `_remoteEventIsPast`. The `_pastColor = Color(0xFF8E8E93)` is used by both `calendar_view.dart` and `day_view_sheet.dart`.

**Drop targets**: each day cell is a `PlusDropTarget` that accepts `PlusDragPayload`, routing to `_handleDropOnDay` in `HomeShell` which opens a Task/Event picker.

`day_view_sheet.dart` — modal sheet for the tapped day; shows tasks + events + remote events + birthdays + an inline creation picker. Receives `contactController` so it can list birthdays and route creation to `showContactCreationSheet` when the user picks "Birthday".

`event_creation_sheet.dart` / `event_detail_view.dart` — local event creation + editor. Detail also supports duration / reminder offsets.

### Google Calendar integration (`lib/src/integrations/google/`)

Lets users view their Google Calendar events alongside Planom events and create/edit/delete events in their existing Google calendars. **No-duplication invariant:** a Google event lives only in Google (in memory + on-disk JSON cache for offline display); a Planom event lives only in SQLite. Neither store ever writes into the other. `CalendarView` and `DayViewSheet` merge the two streams in the view layer.

| File | Purpose |
|------|---------|
| `oauth_config.dart` | `kGoogleIosClientId`, `kGoogleAndroidClientId`, `kGoogleServerClientId`, `kGoogleCalendarScopes`, `isGoogleSignInConfigured`. |
| `google_auth_service.dart` | Wraps `google_sign_in`. `trySilentSignIn`, `signIn`, `signOut`, `authClient()`. |
| `google_calendar_api.dart` | Thin wrapper over `googleapis` `CalendarApi`. `listCalendars`, `listEvents` (incremental via syncToken), `insertEvent`, `patchEvent`, `deleteEvent`. |
| `remote_event.dart` | `RemoteEvent` model (in-memory only), `GoogleCalendarMeta`, `RemoteEventDraft`, Google ↔ Planom field mapping (incl. exclusive-end-date handling for multi-day all-day events). |
| `google_calendar_cache.dart` | Best-effort JSON snapshot at `<docs>/google_calendar_cache.json` — populates the calendar on cold start before refresh completes, and used when offline. |
| `google_calendar_controller.dart` | `ChangeNotifier`. `load`, `connect`, `disconnect`, `refreshCalendars`, `setSelectedCalendars`, `setDefaultCalendar`, `eventsForDate`, `refresh`, `createEvent`, `updateEvent`, `deleteEvent`. |
| `lib/src/settings/google_calendar_settings_view.dart` | Connect/disconnect, calendar checklist, default-calendar picker, "Sync now", last-synced timestamp, error banner. |
| `lib/src/calendar/remote_event_detail_view.dart` | Full-screen editor for a remote event. Read-only calendars disable the fields and expose an "Open in Google Calendar" button via `url_launcher`. |

**Controller lifetime:** instantiated globally in `main.dart` alongside `SettingsController`/`SecurityService` — **NOT** inside `SpaceManager`. The Google connection is shared across every space.

**Sync strategy:** on connect, Planom fetches all calendars + first window of events (6 months back, 18 months forward) and stores a `nextSyncToken` per calendar. Subsequent refreshes are incremental — on `410 Gone` the controller falls back to a full window re-fetch. `refresh()` is called on `load()` (after silent sign-in succeeds), after `setSelectedCalendars`, and from the "Sync now" row in settings.

**Event creation:** `EventCreationSheet` shows a calendar-picker row when the user is signed in and has at least one writable, selected calendar. The picker contains `Planom (local)` plus each selected calendar; the default is the user-configured default. Picking Planom calls `EventController.addEvent`; picking a Google calendar calls `GoogleCalendarController.createEvent`. No event is ever written to both stores.

**Read-only calendars** (subscribed holidays, shared-view) surface as `RemoteEvent.isReadOnly = true`. The detail view disables editable fields and only exposes "Open in Google Calendar".

**iOS setup required:** replace placeholders in `ios/Runner/Info.plist` (`GIDClientID` + the reversed-client-ID `CFBundleURLSchemes` entry) and set `kGoogleIosClientId` in `oauth_config.dart`. Until those are filled in, `isGoogleSignInConfigured` returns false and the settings page shows a "setup required" state — no network calls attempted.

### Contacts feature (`lib/src/contacts/`) — new

Lists with `listType = ListType.birthdays` render contacts instead of tasks. Contacts are first-class entities split from `Task` in DB v25; the migration moves any existing birthday tasks into the new `contacts` table and recreates `tasks` without the birthday columns.

| File | Purpose |
|------|---------|
| `contact_controller.dart` | (see Controllers above) |
| `contact_creation_sheet.dart` | Modal sheet — name, date (with year-toggle), optional note, optional reminder offsets. |
| `contact_detail_view.dart` | Full editor with autosave; toggle isCompletable, manage reminders. |
| `contact_list_view.dart` | Birthday list view; grouped by celebration year (this year first, then next), age shown if `birthYear` is set. |
| `contact_row.dart` | Row with pink gift icon (or gray checkbox if `isCompletable` + completed), name, celebration date, age, optional note snippet. |

Plus-button drop on a Birthdays-type list opens `showContactCreationSheet` instead of the task sheet (handled in `HomeShell._handleDropOnList`). Birthday chips appear on the relevant day in `CalendarView` via `ContactController.contactsForDate(date)`.

### Search feature (`lib/src/search/`) — new

Global full-text search across tasks, notes, and events using SQLite FTS5.

| File | Purpose |
|------|---------|
| `search_view.dart` | Full-screen search; `CupertinoSearchTextField` → debounced (200 ms) `DatabaseService.searchAll`. Results grouped by Tasks / Notes / Events. Tap task / note → detail; events are read-only previews. |
| `search_pull_scope.dart` | Gesture detector wrapper for scroll views. On overscroll/bounce-back it animates a hidden search bar from the top; >30 % reveal on release latches it open. Tap the bar → `SearchView`. Currently wired into `CalendarView`. |

Contacts are intentionally **not** indexed for search yet.

### Settings feature (`lib/src/settings/`)

| File | Purpose |
|------|---------|
| `settings_controller.dart` | (see Controllers above) |
| `settings_service.dart` | Persists `ThemeMode` to `SharedPreferences`. |
| `settings_view.dart` | Settings tab root — sections: Appearance, Font, Tab Bar, Tasks (field prefs), Notes, Notifications, Security, Sync, Data, Storage, Spaces, Google Calendar, About. |
| `settings_menu.dart` / `settings_widgets.dart` | Reusable row/section building blocks (link rows, switch rows, info rows). |
| `appearance_view.dart` | Theme (Light/System/Dark), 12-swatch accent, 7-swatch completion color. |
| `font_picker_view.dart` | Browses all ~1500 Google Fonts. `CupertinoSearchTextField` filters. Connectivity check (`InternetAddress.lookup('fonts.gstatic.com')`); offline + uncached fonts grayed out. ⋯ → "Edit Preview Text". |
| `font_cache.dart` | `FontCache` singleton; persists `Set<String>` of seen keys + custom preview text to `<docsDir>/font_cache.json`. |
| `module_settings_views.dart` | Per-module setting screens (Tasks field visibility, Notes markdown toggle, etc.). |
| `tasks_settings_view.dart` | Tasks-module screen — toggles for individual `TaskFieldPrefs` fields, folder-count mode, hide-tab-labels, show-add-folder-button. |
| `notifications_view.dart` | Permission gate + per-feature toggles (badge, reminders). |
| `security_view.dart` | PIN/password setup, biometric toggle (gated by `supportsBiometricAuth`), change-password flow. |
| `sync_settings_view.dart` | Backend picker (iCloud / disabled), passphrase setup, manual "Push now" / "Pull now", last-synced timestamp. |
| `spaces_view.dart` | Add / rename / delete / switch space; refuses to delete default or last remaining space. |
| `storage_view.dart` | Per-space storage breakdown + "Clear Fonts Cache" / "Clear Temp" / "Clear Orphan Icons" actions. |
| `storage_analyzer.dart` | `analyzeSpace(...)`, `analyzeCustomIcons`, `analyzeFontsCache`, `analyzeTempCache`, `clearFontsCache`, `clearTempCache`, `clearOrphanIcons(referenced)`. DB-bucket sizes are estimated via `utf8.encode(jsonEncode(rows)).length`; file buckets are actual sizes. |
| `data_view.dart` | Export Backup, Import Backup, Reset User Data (confirms hard, then `BackupService.hardReset`). |
| `backup_service.dart` | (see Controllers above) |
| `backup_crypto.dart` | AES-256-GCM + PBKDF2 envelope encryption (see Sync). |
| `smart_list_prefs.dart` | `SmartListPrefs` — `today` / `tomorrow` / `upcoming` / `allTasks` / `completed` / `trash` / `notesTrash` visibility (`show` / `showIfNotEmpty` / `hidden`), `hideTabLabels`, `showAddFolderButton`, `showNotesAddFolderButton`, `notesUseMarkdown`. Stored as `<docsDir>/smart_list_prefs.json`; included in backup payloads. |
| `google_calendar_settings_view.dart` | (see Google Calendar) |

**Appearance color presets:**
```dart
// Accent options (12):
[0xFFFF4D00, 0xFFFF3B30, 0xFFFF9500, 0xFFFFCC00, 0xFF34C759,
 0xFF00C7BE, 0xFF30B0C7, 0xFF007AFF, 0xFF5856D6, 0xFFAF52DE,
 0xFFFF2D55, 0xFFA2845E]

// Completion color options (7):
[0xFF34C759, 0xFF00C7BE, 0xFF007AFF, 0xFF5856D6,
 0xFFFF9500, 0xFFFF2D55, 0xFF8E8E93]
```

### Font system (`lib/src/theme/app_fonts.dart`)

- `kSystemFontKey = '__system__'` — sentinel for the platform default font.
- `fontDisplayName(key)` — converts camelCase Google Fonts key to a human-readable name (handles numeric suffixes like `'sourceSans3'` → `'Source Sans 3'`).
- `buildCupertinoTextTheme(fontKey)` — builds a `CupertinoTextThemeData` with the font applied to every Cupertino text role; returns defaults for `kSystemFontKey` or unknown keys.

### Design tokens (`lib/src/theme/app_theme.dart`)

Use the statics — never hard-code these values at call sites.
- `AppColors.accent` — mutable `static Color` (default `0xFFFF4D00`); user-configurable via Settings → Appearance → Accent Color; **not `const`** — do not use in `const` widget constructors.
- `AppColors.systemGreen` — mutable `static Color` (default `0xFF34C759`); user-configurable via Settings → Appearance → Completion Color; **not `const`**.
- `AppColors.shadow` — `static const Color(0x30000000)` — dropdown / panel drop-shadow (still const).
- `AppDurations.transition` — `Duration(milliseconds: 180)` — standard page transition; baked into `FastRoute`.
- Active tab label/icon: `CupertinoColors.label`; inactive: `CupertinoColors.secondaryLabel` (dynamic — resolve correctly in light/dark).
- Checkbox: 22×22 rounded rect (radius 6), filled accent when checked. Top-aligned with the first line of the task title.

**`const` warning**: because `AppColors.accent` / `AppColors.systemGreen` are mutable statics, any widget tree referencing them cannot be `const`. Remove `const` from the nearest enclosing constructor whenever you add a reference.

### Shared utilities (`lib/src/utils/`)

- `fast_route.dart` — `FastRoute<T> extends CupertinoPageRoute<T>` with 180 ms transition. **Always use FastRoute, never bare `CupertinoPageRoute`.**
- `platform_capabilities.dart` — `PlatformCapabilities` predicates (see Platforms).
- `dropdown_overlay.dart` — `DropdownOverlayMixin` on `State<T>`: provides `showDropdown(context, builder)` that inserts an `OverlayEntry`, exposes a `dismiss()` callback, and auto-removes the entry in `dispose()` so the overlay can't leak when the host route is popped.
- `dropdown_row.dart` — `DropdownRow` widget (leading icon + label + optional destructive color); used inside dropdown overlays and ⋯ menus.
- `selection_menu.dart` — **unified selection menu** replacing all `CupertinoActionSheet` usage. `showSelectionMenu<T>({context, options, current?, title?, anchor})` returns `Future<T?>`. Anchors:
  - `SelectionMenuAnchor.center` (default) — centered overlay with max width 280; used for row-triggered pickers.
  - `SelectionMenuAnchor.topRight` — pinned `top: safeTop + 44 + 4, right: 8, width: 220`; used for nav-bar ⋯ menus.
- `confirm_dialogs.dart` — `confirmMoveToTrash(context, {name, body?, isFolder})` and `confirmHardDelete(context, {title, body, confirmLabel?})` — canonical Cupertino confirmation dialogs.
- `item_info_sheet.dart` — `showItemInfoSheet(context, {creationDate, modifiedDate?, completionDate?})` — small modal showing the relevant timestamps.
- `duration_picker.dart` — `showDurationPicker(context, current?)` returns `Future<int?>` (null = cleared / no change). Presets 15m, 30m, 45m, 60m, 90m, 120m, 180m, 240m, plus Custom (CupertinoTimerPicker). `formatDuration(int minutes)` → human-readable string.
- `reminder_picker.dart` — `showReminderPicker(context, current)` returns `Future<List<int>?>` (null = cancelled). Sections: "Before" (at time / 5/10/15/30 min / 1/2 h / 1 d before / custom) and "After" (1 h / 1 d / custom). `formatReminderOffsets(offsets, S)` — summary string.
- `reorder_drag.dart` — standardised long-press reorder UI:
  - `ReorderDragData<T>` — typed payload (`folder`, `list`, `noteFolder`, `note`) so folder drags can't accidentally hit note targets.
  - `ReorderableRow` — wraps a row in a 400 ms `LongPressDraggable`; lifted feedback is a rounded card with shadow; original fades to 30 % opacity.
  - `ReorderableDropZone` — `DragTarget` paired with a row; shows a 2 px accent line at the top of the target on valid hover.
  - `ReorderableTrailingSlot` — invisible 12 px end-of-list drop zone; shows the accent bar on hover.
- `selection_controller.dart` — multi-select state. `SelectionController` extends `ChangeNotifier`; tracks `active`, `selectedIds`, `kind` (`SelectionItemKind { task, note, folder, list, contact, mixed }`). Kind locks to the first item; mismatched toggles are ignored so the UI stays consistent.
- `selection_toolbar.dart` — bottom toolbar shown while selection is active. `SelectionAction { label, icon, onTap, isDestructive }`. Sized to clear the tab bar via `bottomInset`.
- `selection_checkbox.dart` — iOS Reminders/Mail-style filled-circle checkbox; uses `AppColors.accent`.
- `plus_drag_controller.dart` / `plus_drag_payload.dart` — `PlusDragController` carries optional callbacks (`onDropOnList`, `onDropOnFolder`, `onDropOnSection`, `onDropOnDay`, `onDropOnNoteFolder`, `onDropOnNotesRoot`, `onDropOnSmartList`, `onDropOnAddFolderButton`, `onDropOnNotesAddFolderButton`) exposed through `PlusDragScope` (InheritedWidget). `PlusDropTarget` wraps a widget in a `DragTarget<PlusDragPayload>` that highlights on hover (orange-tinted box) and calls `onAccept` on drop. `PlusDropSmartList` enum identifies smart-list drop variants.
- `undo_controller.dart` — `UndoController` (`ChangeNotifier`) + `UndoScope` (InheritedWidget) + `UndoBanner` widget. `controller.show({label, onUndo})` schedules a 5-second banner with a Revert button; latest call wins (rapid-fire deletes don't pile up — only the most recent banner counts down). Used by every soft-delete site (`UndoScope.of(context).show(...)`) and by event delete (which doesn't soft-delete but still wants revert).

**Duration picker pattern** (task detail, task creation, event detail, event creation): `showSelectionMenu<int>` with preset minutes plus a sentinel `value: -1, isDestructive: true` for "No Duration / Clear". Callers: `if (result == null) return currentValue; if (result == -1) return null; return result;`.

### Selection mode (multi-select) pattern

Selection mode is the canonical batch-action UX, available on Inbox, Today, Tomorrow, Upcoming, All Tasks, Completed, every user list/section, the Tasks root (folders + lists), Notes root, and every note folder.

1. User taps "Select" in the nav-bar ⋯ menu.
2. View instantiates a `SelectionController` (kind-locked on first toggle) and rebuilds with a checkbox in front of every row + a `SelectionToolbar` at the bottom.
3. Rows tap to toggle (also the checkbox itself toggles); mismatched-kind rows are ignored silently.
4. Batch actions on the toolbar iterate `controller.selectedIds`; common operations are delete (with `UndoController.show` covering the bulk), toggle complete, set due date, and move to list/folder.
5. "Cancel" in the nav bar clears the selection and exits the mode.

`SelectableTaskListShell` is the shared shell used by every smart task list; it takes a `tasks()` lambda so it always renders the current state of the controller.

### Plus-button drag pattern

The floating accent-colored `+` button can be **dragged** instead of tapped. Drop it on:
- A list row → opens task creation scoped to that list (or contact creation if it's a Birthdays list).
- A folder row → opens task creation (the user can still pick a list inside that folder from the sheet).
- A section header → opens task creation pre-filled with that section.
- A calendar day cell → opens a Task/Event picker, then routes to the appropriate sheet pre-filled with that date.
- A note folder row → pushes a new blank `NoteDetailView` scoped to that folder.
- The Notes root area → pushes a new root-level `NoteDetailView`.
- A smart list (Inbox / Today / Tomorrow / Upcoming / All Tasks) → opens task creation with the smart-list defaults (Today/Tomorrow stamp `dueDate`; Upcoming defaults to today+2; All Tasks falls back to Inbox).
- The "+ Folder" button at the bottom of Tasks/Notes → opens the create-folder sheet.

The drop targets are `PlusDropTarget` widgets wired through `PlusDragScope`; the callbacks live in `HomeShell._handleDrop*` and route to the correct sheet/navigator.

### Undo banner

Every destructive action shows an `UndoBanner` for 5 seconds with a "Revert" button:
- Soft-delete (task, note, contact, list, folder, section).
- Bulk deep-delete (folder with subfolders + lists + tasks all share one `deletedDate`; the banner reverts via `restoreAt(deletedDate)`).
- Event delete (hard-delete; banner's revert callback re-inserts the same Event).
- Selection-mode batch delete.

The banner sits inside the home shell's `Stack` (above the tab bar / sidebar) so it's visible from anywhere in the tree. Only the latest action counts — a fresh `show` cancels the previous timer.

### Localization

**Hand-rolled** — no `gen-l10n`, no `.arb` codegen, no `l10n.yaml`. Strings live in `lib/src/localization/strings.dart` as a nested `_translations: Map<String, Map<String, String>>` (locale code → key → translation). The `S` class exposes named getters (e.g. `s.appTitle`, `s.tabTasks`) and falls back to English for any missing key. The legacy `lib/src/localization/app_en.arb` file is **stale and unused**.

Adding a new string:
1. Add the English entry to the `'en'` table inside `_translations`.
2. Add a named getter on `S` (e.g. `String get newKey => t('newKey');`).
3. Add translations to the other 9 locales — debug builds will log any missing keys via `_debugReportMissingKeys()`.

Adding a new locale: extend `kSupportedLocales` and `kLanguageNames`, then provide a full table in `_translations`.

`AppLocalizations.delegate` is registered alongside `GlobalMaterialLocalizations`, `GlobalCupertinoLocalizations`, and `GlobalWidgetsLocalizations` in `app.dart`. Both Material delegates are needed because `showModalBottomSheet` (used for sheets) is a Material widget.

**Supported locales** (10): `en`, `uk`, `es`, `fr`, `de`, `it`, `pt`, `ru`, `zh`, `ja`.

**Curly-quote hazard**: the Edit tool can silently introduce Unicode curly apostrophes (U+2018 / U+2019) into `strings.dart`, which breaks Dart string parsing. If you see `Error: The non-ASCII character '‘' can't be used in identifiers`, fix via Python byte replacement rather than a text editor:
```python
content = open('lib/src/localization/strings.dart', 'rb').read()
fixed = content.replace(b'\xe2\x80\x98', b"'").replace(b'\xe2\x80\x99', b"'")
open('lib/src/localization/strings.dart', 'wb').write(fixed)
```
