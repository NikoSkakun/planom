import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/event.dart';
import '../notifications/notification_service.dart';

class EventController with ChangeNotifier {
  EventController(this._db);

  final DatabaseService _db;
  List<Event> _events = [];

  List<Event> get events => List.unmodifiable(_events);

  Event? eventById(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<Event> eventsForDate(DateTime date) => _events
      .where((e) =>
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day)
      .toList();

  Future<void> load() async {
    _events = await _db.getEvents();
    notifyListeners();
  }

  Future<void> addEvent(Event event) async {
    await _db.insertEvent(event);
    _events = [event, ..._events];
    notifyListeners();
    if (event.reminderOffsets.isNotEmpty) {
      NotificationService.instance.scheduleEventReminders(event);
    }
  }

  Future<void> updateEvent(Event updated) async {
    await _db.updateEvent(updated);
    final i = _events.indexWhere((e) => e.id == updated.id);
    if (i == -1) return;
    _events = [..._events]..[i] = updated;
    notifyListeners();
    NotificationService.instance.scheduleEventReminders(updated);
  }

  Future<void> deleteEvent(String id) async {
    await _db.permanentlyDeleteEvent(id);
    _events = _events.where((e) => e.id != id).toList();
    notifyListeners();
    NotificationService.instance.cancelEventReminders(id);
  }
}
