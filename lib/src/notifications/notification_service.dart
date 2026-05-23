import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/event.dart';
import '../models/task.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  static Future<void> initTimezone() async {
    tz_data.initializeTimeZones();
    // Use local timezone; on iOS this resolves automatically
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
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final result = await iOS?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    _permissionGranted = result ?? false;
    return _permissionGranted;
  }

  Future<bool> checkPermission() async {
    await init();
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final status = await iOS?.checkPermissions();
    _permissionGranted = status?.isEnabled ?? false;
    return _permissionGranted;
  }

  // ── Task reminders ─────────────────────────────────────────────────────────

  Future<void> scheduleTaskReminders(Task task) async {
    await _cancelFor(task.id, task.reminderOffsets);
    if (!_permissionGranted) await checkPermission();
    if (!_permissionGranted) return;
    if (task.reminderOffsets.isEmpty) return;
    if (task.dueDate == null) return;

    final baseTime = _taskDateTime(task);
    if (baseTime == null) return;

    for (final offset in task.reminderOffsets) {
      final fireAt = baseTime.add(Duration(minutes: offset));
      if (fireAt.isBefore(DateTime.now())) continue;
      await _schedule(
        id: _notifId(task.id, offset),
        title: task.title,
        body: _offsetLabel(offset),
        fireAt: fireAt,
      );
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    // Cancel using all possible offsets range — or we just cancel via group
    // Since we can't enumerate what was scheduled without storing state,
    // use a deterministic ID pattern to cancel all 20 possible slots.
    for (int i = 0; i < 20; i++) {
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

    for (final offset in event.reminderOffsets) {
      final fireAt = baseTime.add(Duration(minutes: offset));
      if (fireAt.isBefore(DateTime.now())) continue;
      await _schedule(
        id: _notifId(event.id, offset),
        title: event.title,
        body: _offsetLabel(offset),
        fireAt: fireAt,
      );
    }
  }

  Future<void> cancelEventReminders(String eventId) async {
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(_notifSlot(eventId, i));
    }
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _cancelFor(String id, List<int> offsets) async {
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(_notifSlot(id, i));
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
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

  /// Deterministic notification ID: uses a slot index (0-19) per item.
  /// When scheduling, assigns offsets to slots in order.
  int _notifSlot(String itemId, int slotIndex) {
    final hex = itemId.replaceAll('-', '').substring(0, 8);
    final base = int.tryParse(hex, radix: 16) ?? itemId.hashCode;
    return (base ^ (slotIndex * 97)) & 0x7FFFFFFF;
  }

  int _notifId(String itemId, int offsetMinutes) {
    // Find the slot for this offset relative to previously set offsets.
    // Since we cancel all slots before scheduling, we use a hash of offset.
    final hex = itemId.replaceAll('-', '').substring(0, 8);
    final base = int.tryParse(hex, radix: 16) ?? itemId.hashCode;
    return (base ^ ((offsetMinutes + 10000) * 31)) & 0x7FFFFFFF;
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
