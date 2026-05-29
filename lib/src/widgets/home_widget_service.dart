import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../calendar/event_controller.dart';
import '../contacts/contact_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../notifications/notification_service.dart';
import '../routines/routine_controller.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/platform_capabilities.dart';
import 'widget_data_builder.dart';
import 'widget_keys.dart';

/// Pushes "Today" data into the shared app-group container so the iOS
/// WidgetKit extension can render home-screen / lock-screen widgets, and wires
/// the interactivity (iOS 17+) background callback that lets the user check
/// off a task or record a routine directly from a widget.
///
/// All methods are safe no-ops on platforms without widget support
/// ([PlatformCapabilities.supportsHomeWidgets]).
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || !PlatformCapabilities.supportsHomeWidgets) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    // The dart entry-point invoked from the widget's AppIntent (iOS 17+).
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }

  /// Serialises the active space's "Today" data and hands it to WidgetKit.
  Future<void> pushFromControllers({
    required SettingsController settings,
    required TaskController taskController,
    required EventController eventController,
    required RoutineController routineController,
    required ContactController contactController,
    required FolderController folderController,
    required String spaceName,
    required String activeDbName,
  }) async {
    if (!PlatformCapabilities.supportsHomeWidgets) return;
    final payload = WidgetDataBuilder(
      taskController: taskController,
      eventController: eventController,
      routineController: routineController,
      contactController: contactController,
      folderController: folderController,
      accentColor: settings.accentColor,
      locale: settings.locale,
      spaceName: spaceName,
    ).build();
    await _publish(payload, activeDbName);
  }

  Future<void> _publish(Map<String, dynamic> payload, String activeDbName) async {
    if (!_initialized) await init();
    try {
      await HomeWidget.saveWidgetData<String>(
          kWidgetPayloadKey, jsonEncode(payload));
      await HomeWidget.saveWidgetData<String>(kWidgetActiveDbKey, activeDbName);
      for (final kind in kIosWidgetKinds) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
    } catch (e) {
      // Widget updates are best-effort — never let them break the app.
      debugPrint('[widgets] push failed: $e');
    }
  }
}

/// Background isolate entry-point invoked by the widget's `AppIntent` when the
/// user taps an interactive control (iOS 17+). Runs in a headless Flutter
/// engine with no access to the app's live controllers, so it opens the active
/// space's database directly, applies the mutation, and re-publishes the
/// widget payload.
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  if (uri == null) return;
  final id = uri.queryParameters['id'];
  if (id == null || id.isEmpty) return;

  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    final dbName =
        await HomeWidget.getWidgetData<String>(kWidgetActiveDbKey) ?? 'planom.db';
    final db = DatabaseService(dbName: dbName);

    // Reminders may be (re)scheduled by toggleCompleted; make the timezone DB
    // available so the local-notifications plugin doesn't throw.
    await NotificationService.initTimezone();

    final taskController = TaskController(db);
    await taskController.load();
    final routineController = RoutineController(db);
    await routineController.load();

    switch (uri.host) {
      case WidgetDeepLink.completeTask:
        if (taskController.taskById(id) != null) {
          await taskController.toggleCompleted(id);
        }
        break;
      case WidgetDeepLink.recordRoutine:
        final matches = routineController.routines.where((r) => r.id == id);
        if (matches.isNotEmpty) {
          await routineController.recordProgress(matches.first);
        }
        break;
      default:
        return;
    }

    // Rebuild the payload from the freshly-mutated database. Appearance /
    // locale live in the global planom.db, which we read directly here so the
    // widget keeps the user's accent + language without the full app running.
    final globalDb =
        dbName == 'planom.db' ? db : DatabaseService(dbName: 'planom.db');
    final settings = await _loadSettingsSnapshot(globalDb);

    final eventController = EventController(db);
    await eventController.load();
    final contactController = ContactController(db);
    await contactController.load();
    final folderController = FolderController(db);
    await folderController.load();

    final payload = WidgetDataBuilder(
      taskController: taskController,
      eventController: eventController,
      routineController: routineController,
      contactController: contactController,
      folderController: folderController,
      accentColor: settings.accent,
      locale: localeFromCode(settings.localeCode),
      spaceName: await _activeSpaceName(dbName),
    ).build();

    await HomeWidget.saveWidgetData<String>(
        kWidgetPayloadKey, jsonEncode(payload));
    for (final kind in kIosWidgetKinds) {
      await HomeWidget.updateWidget(iOSName: kind);
    }
  } catch (e) {
    debugPrint('[widgets] interactivity callback failed: $e');
  }
}

class _SettingsSnapshot {
  const _SettingsSnapshot(this.accent, this.localeCode);
  final Color accent;
  final String? localeCode;
}

/// Reads accent color + locale from the global `app_settings` table without
/// constructing the full SettingsController (which pulls in SharedPreferences
/// and other foreground-only dependencies).
Future<_SettingsSnapshot> _loadSettingsSnapshot(DatabaseService db) async {
  Color accent = AppColors.accent;
  String? localeCode;
  try {
    final rows = await db.getAppSettings();
    final map = <String, String>{
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
    final v = int.tryParse(map['accent_color'] ?? '');
    if (v != null) accent = Color(v);
    localeCode = map['locale'];
  } catch (_) {/* fall back to defaults */}
  return _SettingsSnapshot(accent, localeCode);
}

/// Best-effort lookup of the active space's display name from spaces.json so
/// the widget header can show which space it reflects.
Future<String> _activeSpaceName(String dbName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'spaces.json'));
    if (!await file.exists()) return 'Planom';
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final activeId = data['activeSpaceId'] as String? ?? 'default';
    final spaces = (data['spaces'] as List?) ?? const [];
    for (final s in spaces) {
      if (s is Map && s['id'] == activeId) {
        return (s['name'] as String?) ?? 'Planom';
      }
    }
  } catch (_) {/* ignore */}
  return 'Planom';
}
