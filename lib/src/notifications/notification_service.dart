import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/event.dart';
import '../models/task.dart';
import '../utils/platform_capabilities.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  /// Maximum reminders per item. Scheduling and cancellation both iterate
  /// slots `0.._maxSlots-1`, so the two must use the same bound to stay in sync.
  static const _maxSlots = 20;

  static Future<void> initTimezone() async {
    tz_data.initializeTimeZones();
    // NOTE: this picks the first IANA zone whose CURRENT offset matches the
    // device, which can select a zone with the wrong DST rules — a reminder
    // scheduled across a DST boundary may then fire an hour off. The correct
    // fix is to read the device's IANA zone name via the `flutter_timezone`
    // plugin and pass it to `tz.getLocation`; left as a follow-up to avoid
    // adding an unverified native dependency here.
    final localTz = DateTime.now().timeZoneOffset;
    final locations = tz.timeZoneDatabase.locations;
    for (final name in locations.keys) {
      try {
        final loc = tz.getLocation(name);
        final now = tz.TZDateTime.now(loc);
        if (now.timeZoneOffset == localTz) {
          tz.setLocalLocation(loc);
          break;
        }
      } catch (_) {}
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!PlatformCapabilities.supportsLocalNotifications) {
      // Mark initialised so subsequent calls short-circuit cheaply on
      // platforms we don't schedule on (Linux/Windows/Android).
      _initialized = true;
      return;
    }
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(initSettings);
    } catch (_) {
      // Some hosts (notably the macOS App Sandbox without notification
      // entitlements) fail the channel handshake here; we'd rather have
      // a working app without notifications than a crashed launch.
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    if (!PlatformCapabilities.supportsLocalNotifications) return false;
    final darwin = _darwinPlugin();
    final result = await darwin?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    _permissionGranted = result ?? false;
    return _permissionGranted;
  }

  Future<bool> checkPermission() async {
    await init();
    if (!PlatformCapabilities.supportsLocalNotifications) return false;
    final darwin = _darwinPlugin();
    final status = await darwin?.checkPermissions();
    _permissionGranted = status?.isEnabled ?? false;
    return _permissionGranted;
  }

  /// Returns whichever Darwin (iOS/macOS) implementation is registered on the
  /// running host, or null on platforms without one. `IOS…Plugin` is the
  /// concrete type even on macOS — the platform interface is shared.
  dynamic _darwinPlugin() {
    if (PlatformCapabilities.isMacOS) {
      return _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
    }
    return _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
  }

  // ── Task reminders ─────────────────────────────────────────────────────────

  Future<void> scheduleTaskReminders(Task task) async {
    await cancelTaskReminders(task.id);
    if (!_permissionGranted) await checkPermission();
    if (!_permissionGranted) return;
    if (task.reminderOffsets.isEmpty) return;
    if (task.dueDate == null) return;

    final baseTime = _taskDateTime(task);
    if (baseTime == null) return;

    final offsets = task.reminderOffsets.take(_maxSlots).toList();
    for (int i = 0; i < offsets.length; i++) {
      final fireAt = baseTime.add(Duration(minutes: offsets[i]));
      if (fireAt.isBefore(DateTime.now())) continue;
      await _schedule(
        id: _notifSlot(task.id, i),
        title: task.title,
        body: _offsetLabel(offsets[i]),
        fireAt: fireAt,
      );
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    if (!PlatformCapabilities.supportsLocalNotifications) return;
    for (int i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(_notifSlot(taskId, i));
    }
  }

  // ── Event reminders ────────────────────────────────────────────────────────

  Future<void> scheduleEventReminders(Event event) async {
    await cancelEventReminders(event.id);
    if (!_permissionGranted) await checkPermission();
    if (!_permissionGranted) return;
    if (event.reminderOffsets.isEmpty) return;

    final baseTime = _eventDateTime(event);
    if (baseTime == null) return;

    final offsets = event.reminderOffsets.take(_maxSlots).toList();
    for (int i = 0; i < offsets.length; i++) {
      final fireAt = baseTime.add(Duration(minutes: offsets[i]));
      if (fireAt.isBefore(DateTime.now())) continue;
      await _schedule(
        id: _notifSlot(event.id, i),
        title: event.title,
        body: _offsetLabel(offsets[i]),
        fireAt: fireAt,
      );
    }
  }

  Future<void> cancelEventReminders(String eventId) async {
    if (!PlatformCapabilities.supportsLocalNotifications) return;
    for (int i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(_notifSlot(eventId, i));
    }
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    if (!PlatformCapabilities.supportsLocalNotifications) return;
    await _plugin.cancelAll();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    if (!PlatformCapabilities.supportsLocalNotifications) return;
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(iOS: darwinDetails, macOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  DateTime? _taskDateTime(Task task) {
    if (task.dueDate == null) return null;
    final d = task.dueDate!;
    final doTime = task.doTime;
    if (doTime == null) {
      return DateTime(d.year, d.month, d.day, 9, 0); // default 9 AM
    }
    return DateTime(d.year, d.month, d.day, doTime ~/ 60, doTime % 60);
  }

  DateTime? _eventDateTime(Event event) {
    final d = event.date;
    final doTime = event.doTime;
    if (doTime == null) {
      return DateTime(d.year, d.month, d.day, 9, 0);
    }
    return DateTime(d.year, d.month, d.day, doTime ~/ 60, doTime % 60);
  }

  /// Deterministic notification ID derived from the item id and a slot index.
  /// Reminders are assigned to slots `0.._maxSlots-1` in offset order, and
  /// cancellation clears the same slot range — so the formula here must be the
  /// single source of truth for both scheduling and cancelling.
  int _notifSlot(String itemId, int slotIndex) {
    final hex = itemId.replaceAll('-', '').substring(0, 8);
    final base = int.tryParse(hex, radix: 16) ?? itemId.hashCode;
    return (base ^ (slotIndex * 97)) & 0x7FFFFFFF;
  }

  String _offsetLabel(int offset) {
    if (offset == 0) return 'Scheduled';
    if (offset < 0) {
      final abs = -offset;
      if (abs < 60) return '$abs min before';
      if (abs < 1440) return '${abs ~/ 60} hr before';
      return '${abs ~/ 1440} day(s) before';
    } else {
      if (offset < 60) return '$offset min after';
      if (offset < 1440) return '${offset ~/ 60} hr after';
      return '${offset ~/ 1440} day(s) after';
    }
  }
}
