/// Shared constants for the iOS home-screen / lock-screen widgets.
///
/// These values are duplicated on the native side (Swift) in
/// `ios/PlanomWidget/WidgetData.swift` — keep them in sync. The Flutter app
/// writes a single JSON payload into the shared app-group container under
/// [kWidgetPayloadKey]; the WidgetKit extension reads it back to render.
library;

/// App Group identifier shared between the Runner app and the widget
/// extension. Must match the `com.apple.security.application-groups` entry in
/// both `Runner.entitlements` and `PlanomWidget.entitlements`, and the
/// `suiteName` used by the Swift `UserDefaults` loader.
const String kWidgetAppGroupId = 'group.app.planom';

/// Key under which the full JSON payload is stored via `HomeWidget`.
const String kWidgetPayloadKey = 'planom_widget_payload';

/// Key holding the active space's database filename, so the background
/// interactivity isolate can mutate the correct space's data.
const String kWidgetActiveDbKey = 'planom_widget_active_db';

/// iOS widget kind identifiers — must match the `kind:` strings declared by
/// each `Widget` in the Swift extension. Used when asking WidgetKit to reload
/// a specific timeline.
const List<String> kIosWidgetKinds = [
  'PlanomTodayTasksWidget',
  'PlanomAgendaWidget',
  'PlanomRoutinesWidget',
  'PlanomStatsWidget',
];

/// Custom URL scheme used for widget → app deep links.
const String kWidgetScheme = 'planom';

/// Deep-link hosts. A widget tap opens `planom://<host>[?id=…]`.
class WidgetDeepLink {
  WidgetDeepLink._();

  /// Open the Tasks tab (Today / smart lists).
  static const String today = 'today';
  static const String tasks = 'tasks';

  /// Open the Calendar tab.
  static const String calendar = 'calendar';

  /// Open the Routines tab.
  static const String routines = 'routines';

  /// Open the task-creation sheet.
  static const String addTask = 'add-task';

  /// Open the event-creation sheet.
  static const String addEvent = 'add-event';

  /// Interactive (iOS 17+) — toggle a task's completion. `?id=<taskId>`.
  static const String completeTask = 'complete-task';

  /// Interactive (iOS 17+) — record progress for a routine. `?id=<routineId>`.
  static const String recordRoutine = 'record-routine';
}
