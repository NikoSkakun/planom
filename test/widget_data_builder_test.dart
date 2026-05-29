import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/contacts/contact_controller.dart';
import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/models/contact.dart';
import 'package:planom/src/models/event.dart';
import 'package:planom/src/models/routine.dart';
import 'package:planom/src/models/task.dart';
import 'package:planom/src/routines/routine_controller.dart';
import 'package:planom/src/tasks/task_controller.dart';
import 'package:planom/src/widgets/widget_data_builder.dart';

/// Exercises the widget payload builder end-to-end against real controllers +
/// an FFI database. This is the only testable slice of the iOS widget pipeline
/// (the WidgetKit extension itself can't be unit-tested here), so it guards the
/// JSON contract the native side decodes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late TaskController tasks;
  late EventController events;
  late RoutineController routines;
  late ContactController contacts;
  late FolderController folders;

  setUp(() async {
    db = DatabaseService(
        dbName: 'test_widget_${DateTime.now().microsecondsSinceEpoch}.db');
    tasks = TaskController(db);
    await tasks.load();
    events = EventController(db);
    await events.load();
    routines = RoutineController(db);
    await routines.load();
    contacts = ContactController(db);
    await contacts.load();
    folders = FolderController(db);
    await folders.load();
  });

  Map<String, dynamic> build() => WidgetDataBuilder(
        taskController: tasks,
        eventController: events,
        routineController: routines,
        contactController: contacts,
        folderController: folders,
        accentColor: const Color(0xFFFF4D00),
        locale: const Locale('en'),
        spaceName: 'Personal',
      ).build();

  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  test('empty payload has zeroed counts and stable shape', () {
    final p = build();
    expect(p['accentColor'], '#FF4D00');
    expect(p['spaceName'], 'Personal');
    expect((p['counts'] as Map)['todayTasks'], 0);
    expect(p['todayTasks'], isEmpty);
    expect((p['labels'] as Map)['today'], 'Today');
  });

  test('today task appears with list color and time', () async {
    final list = AppList(name: 'Work', color: 0xFF007AFF);
    await folders.addList(list);
    await tasks.addTask(Task(
      title: 'Ship it',
      dueDate: today(),
      doTime: 540,
      priority: 3,
      listId: list.id,
    ));

    final p = build();
    final list0 = (p['todayTasks'] as List).cast<Map>();
    expect(list0, hasLength(1));
    expect(list0.first['title'], 'Ship it');
    expect(list0.first['minutes'], 540);
    expect(list0.first['priority'], 3);
    expect(list0.first['color'], '#007AFF');
    expect((p['counts'] as Map)['todayRemaining'], 1);
  });

  test('overdue uncompleted task is flagged and rolled into today', () async {
    await tasks.addTask(Task(
      title: 'Late',
      dueDate: today().subtract(const Duration(days: 2)),
    ));
    final p = build();
    final t = (p['todayTasks'] as List).cast<Map>().first;
    expect(t['overdue'], true);
  });

  test('today event is serialized chronologically-friendly', () async {
    await events.addEvent(Event(title: 'Standup', date: today(), doTime: 600));
    await events.addEvent(Event(title: 'All hands', date: today()));
    final p = build();
    final evs = (p['todayEvents'] as List).cast<Map>();
    expect(evs, hasLength(2));
    // All-day (null doTime) sorts last.
    expect(evs.first['title'], 'Standup');
    expect(evs.last['allDay'], true);
  });

  test('routine progress + completion are reported', () async {
    final r = Routine(
      name: 'Water',
      goalType: 'certain_amount',
      goalAmount: 8,
      goalUnit: 'glasses',
      recordAmount: 1,
      frequencyType: 'daily',
      autoReset: 'everyday',
    );
    await routines.addRoutine(r);
    await routines.recordProgress(r);

    final p = build();
    final rj = (p['routines'] as List).cast<Map>().first;
    expect(rj['name'], 'Water');
    expect(rj['progress'], 1);
    expect(rj['goal'], 8);
    expect(rj['done'], false);
    expect((p['counts'] as Map)['routinesTotal'], 1);
  });

  test('birthday today is included', () async {
    final list = AppList(name: 'Birthdays');
    await folders.addList(list);
    final t = today();
    await contacts.addContact(Contact(
      name: 'Sam',
      listId: list.id,
      birthMonth: t.month,
      birthDay: t.day,
      birthYear: t.year - 25,
    ));
    final p = build();
    final b = (p['birthdays'] as List).cast<Map>();
    expect(b, hasLength(1));
    expect(b.first['name'], 'Sam');
    expect(b.first['age'], 25);
  });
}
